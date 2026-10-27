---------------------------------------------------------------------
-- DM2_ParseFightStats_MenuShell.lua — experimental gamepad menu viewer
-- v3.16.0: Phase 2.5 finish (crit exposure polish, CP A/B, experiment loop, pen footer, cohort).
-- Locals top-down (console-safe). Prefer full labels; standard abbreviations only.
---------------------------------------------------------------------

DM2Stats = DM2Stats or {}
local R = DM2Stats

DM2StatsMenuShell = DM2StatsMenuShell or {}
local M = DM2StatsMenuShell

M.name    = "DM2StatsMenuShell"
M.version = "3.18.5"

local WM = WINDOW_MANAGER
local SCENE_NAME = "dm2StatsMenuShellGamepad"
local MENU_ENTRY_ID = 99743

-- Layout: side pad + plate inset — content must sit *inside* the plate, not bleed.
local SHELL_SIDE_PAD = 48
local CONTENT_HEADER_INSET = 126
local CONTENT_FOOTER_INSET = 88  -- leave room for gamepad keybind bar
local CONTENT_PAD = 12
local NAV_CONTENT_GAP = 28
local CONTENT_PLATE_INSET = 20   -- plate edge inside host
local CONTENT_INNER_INSET = 14  -- panels sit inside plate (fixes L/R smudge)
local NAV_RAIL_FRAC = 0.22
local NAV_RAIL_MIN = 220
local NAV_RAIL_MAX = 340

local LIST_ICON = 32
local LIST_ROW_H = 42
local LIST_MAX_ROWS = 14
local DASH_TOP_SKILL_ICON = 28
local DASHBOARD_COL_GAP = 12
local BAR_ICON_SIZE = 36
local SPARK_MAX_BARS = 16
local SPARK_BAR_MAX_H = 40
local TREND_MAX_COLS = 8
local TREND_SPARK_MAX_BARS = 8
local TREND_SPARK_BAR_MAX_H = 36
local TREND_HIST_LINES = 7
local COMP_COLS = 4
local COMP_METRICS = 9 -- includes Build ID + vs #2 notes (Phase 2)
local ROT_TIMELINE_ICONS = 192  -- pool/page cap; dummy parses usually fit on one screen
local PULSE_BLOCKS = 72        -- finer pulse (smaller blocks)
local BUFF_MAIN_ROWS = 12       -- Always-on (left pane)
local BUFF_SIDE_ROWS = 10       -- Sustained + Situational combined (right pane)
local PROC_MAX_ROWS = 12
local INSIGHT_MAX_LINES = 16
local INSIGHT_OPP_ROWS = 5
local INSIGHT_TIP_ROWS = 5
local INSIGHT_SYN_SRC_ROWS = 5
local INSIGHT_SYN_CP_ROWS = 6

local THEME = {
  plateR = 0.07, plateG = 0.06, plateB = 0.055, plateA = 0.94,
  plateEdgeR = 0.62, plateEdgeG = 0.48, plateEdgeB = 0.28, plateEdgeA = 0.72,
  railR = 0.05, railG = 0.045, railB = 0.04, railA = 0.78,
  railEdgeR = 0.50, railEdgeG = 0.40, railEdgeB = 0.24, railEdgeA = 0.45,
  cardR = 0.10, cardG = 0.09, cardB = 0.08, cardA = 0.42,
  cardEdgeR = 0.58, cardEdgeG = 0.46, cardEdgeB = 0.28, cardEdgeA = 0.55,
  titleR = 0.92, titleG = 0.78, titleB = 0.48,
  textR = 0.94, textG = 0.93, textB = 0.90,
  mutedR = 0.72, mutedG = 0.70, mutedB = 0.66,
  frontR = 0.53, frontG = 0.87, frontB = 0.67,
  backR = 0.53, backG = 0.67, backB = 0.87,
}

-- Tab IDs MUST match NAV_ENTRIES list order (1-based). Gamepad list selection
-- uses index and SyncNavListSelection(SetSelectedIndex(currentTab)).
-- 3.14.x bug: ROTATION was moved under WEAVE in NAV but TAB ids stayed old →
-- Rotation opened Buffs, Buffs opened Gear/Build&Sets, Build&Sets opened Rotation.
local TAB = {
  OVERVIEW       = 1,
  DASHBOARD      = 2,
  DAMAGE         = 3,
  WEAVE          = 4,
  ROTATION       = 5,
  BUFFS          = 6,
  GEAR           = 7,
  PROCS          = 8,  -- Build & Sets
  INSIGHTS_DPS   = 9,  -- Parse diagnosis, waste, execution, Next Test
  INSIGHTS_BUILD = 10, -- Build contribution, CP, trial assumptions
  HISTORY        = 11,
}
-- Back-compat alias
TAB.INSIGHTS = TAB.INSIGHTS_DPS

local NAV_ENTRIES = {
  { tab = TAB.OVERVIEW,       label = "Overview",       sub = "Full summary" },
  { tab = TAB.DASHBOARD,      label = "Dashboard",      sub = "At-a-glance" },
  { tab = TAB.DAMAGE,         label = "Damage",         sub = "Skills + effects" },
  { tab = TAB.WEAVE,          label = "Weave",          sub = "Per-skill + DoT" },
  { tab = TAB.ROTATION,       label = "Rotation",       sub = "Icons + pulse" },
  { tab = TAB.BUFFS,          label = "Buffs",          sub = "Self + target" },
  { tab = TAB.GEAR,           label = "Gear",           sub = "Bars + worn" },
  { tab = TAB.PROCS,          label = "Build & Sets",   sub = "Build + set DPS" },
  { tab = TAB.INSIGHTS_DPS,   label = "Insights: DPS",  sub = "Diagnosis + next test" },
  { tab = TAB.INSIGHTS_BUILD, label = "Insights: Build", sub = "Fit + contribution" },
  { tab = TAB.HISTORY,        label = "History",        sub = "Trends + compare" },
}

local TAB_MAX = TAB.HISTORY
local TAB_KEY = {
  [TAB.OVERVIEW] = "overview",
  [TAB.DASHBOARD] = "dashboard",
  [TAB.DAMAGE] = "damage",
  [TAB.WEAVE] = "weave",
  [TAB.BUFFS] = "buffs",
  [TAB.GEAR] = "gear",
  [TAB.PROCS] = "procs",
  [TAB.ROTATION] = "rotation",
  [TAB.INSIGHTS_DPS] = "insightsDps",
  [TAB.INSIGHTS_BUILD] = "insightsBuild",
  [TAB.HISTORY] = "history",
}

local historyOffset = 0
local screenObject = nil
local sceneObject = nil
local fragmentObject = nil
local keybindGroup = nil
local menuEntryAdded = false
local sceneBuildFailed = false
local listPopulateWarned = false
local headerNote = ""

-- Menu-local coach cache ONLY (never attach coach tables to SV.history sessions).
-- Writing coach onto session caused SV re-bloat: coach.cpAbPairs held sessionA/sessionB
-- refs into other history slots; ESO serialization duplicates them (n² growth).
local coachCache = {} -- [cacheKey] = coach

local function coachCacheKey(session)
  if type(session) ~= "table" then return nil end
  if session.completedAt then
    return string.format("c:%s:%s:%s",
      tostring(session.completedAt),
      tostring(session.totalDamage or 0),
      tostring(session.durationMs or 0))
  end
  -- Live (not yet history) session: use table identity via a private token
  if not session._coachTok then
    session._coachTok = string.format("L%d", (tonumber(session.startMs) or 0) + (tonumber(session.totalDamage) or 0))
  end
  return session._coachTok
end

local function detachCoachPersistRefs(coach)
  if type(coach) ~= "table" then return coach end
  if type(coach.cpAbPairs) == "table" then
    for _, p in ipairs(coach.cpAbPairs) do
      if type(p) == "table" then
        p.sessionA = nil
        p.sessionB = nil
      end
    end
  end
  if type(coach.syn) == "table" and type(coach.syn.cps) == "table" then
    for _, c in ipairs(coach.syn.cps) do
      if type(c) == "table" and type(c.abPair) == "table" then
        c.abPair.sessionA = nil
        c.abPair.sessionB = nil
      end
    end
  end
  -- Never embed live SV.experiments.active table (another SV root)
  if type(coach.experiment) == "table" then
    local e = coach.experiment
    coach.experiment = {
      id = e.id,
      title = e.title,
      ruleId = e.ruleId,
      completed = e.completed,
      targetRuns = e.targetRuns,
      runCount = type(e.runs) == "table" and #e.runs or (tonumber(e.runCount) or 0),
    }
  end
  return coach
end

local function setSessionCoach(session, coach)
  if type(session) ~= "table" then return end
  -- Critical: never leave coach on the session table (it is often an SV.history entry)
  session.coach = nil
  coach = detachCoachPersistRefs(coach)
  local key = coachCacheKey(session)
  if key then coachCache[key] = coach end
end

local function getSessionCoach(session)
  if type(session) ~= "table" then return nil end
  -- Ignore any legacy session.coach left in old SV (and clear it)
  if session.coach ~= nil then session.coach = nil end
  local key = coachCacheKey(session)
  if key then return coachCache[key] end
  return nil
end

---------------------------------------------------------------------
-- Platform / format helpers (Tier 0)
---------------------------------------------------------------------
local function isGamepadPreferred()
  if type(IsInGamepadPreferredMode) == "function" then return IsInGamepadPreferredMode() end
  if type(IsInGamepadMode) == "function" then return IsInGamepadMode() end
  if type(IsConsoleUI) == "function" then return IsConsoleUI() end
  if type(ZO_IsConsoleUI) == "function" then return ZO_IsConsoleUI() end
  return false
end

local function clampNum(v, lo, hi)
  if zo_clamp then return zo_clamp(v, lo, hi) end
  return math.max(lo, math.min(v, hi))
end

local function floorNum(v)
  if zo_floor then return zo_floor(v) end
  return math.floor(v)
end

local function fmtInt(n)
  n = tonumber(n) or 0
  n = math.floor(n + 0.5)
  if ZO_CommaDelimitNumber then return ZO_CommaDelimitNumber(n) end
  return tostring(n)
end

local function fmtDps(dps)
  dps = tonumber(dps) or 0
  if dps < 0 then dps = 0 end
  if dps >= 1000000 then return string.format("%.2fm", dps / 1000000) end
  if dps >= 1000 then return string.format("%.1fk", dps / 1000) end
  return string.format("%.0f", dps)
end

-- Signed DPS delta for compare rows (fmtDps clamps negatives — do not use it for deltas)
local function fmtDpsDelta(dps)
  dps = tonumber(dps) or 0
  local sign = (dps > 0) and "+" or (dps < 0) and "−" or ""
  local mag = math.abs(dps)
  if mag >= 1000000 then return sign .. string.format("%.2fm", mag / 1000000) end
  if mag >= 1000 then return sign .. string.format("%.1fk", mag / 1000) end
  if mag < 0.5 then return "0" end
  return sign .. string.format("%.0f", mag)
end

local function fmtPct(x)
  x = tonumber(x) or 0
  return string.format("%.1f%%", x * 100)
end

local function fmtDur(ms)
  ms = tonumber(ms) or 0
  if ms < 0 then ms = 0 end
  local total = ms / 1000
  local mins = math.floor(total / 60)
  local secs = total - (mins * 60)
  return string.format("%d:%04.1f", mins, secs)
end

local function truncateText(text, maxLen)
  text = tostring(text or "?")
  maxLen = tonumber(maxLen) or 18
  if #text <= maxLen then return text end
  return string.sub(text, 1, maxLen - 1) .. "…"
end

-- Strip ESO color codes (|cRRGGBB / |r). Defined early — used by gear/timeline builders.
local function stripColorLocal(text)
  text = tostring(text or "")
  text = text:gsub("|c%x%x%x%x%x%x", "")
  text = text:gsub("|r", "")
  return text
end

local function dashFont(size)
  return string.format("$(BOLD_FONT)|$(KB_%d)|thick-outline:6;soft-shadow-thick", size)
end

local function isBadIconTex(tex)
  if not tex or tex == "" then return true end
  local lower = string.lower(tostring(tex))
  -- ESO missing / unknown ability icons (console often shows a red "?")
  if string.find(lower, "question", 1, true) then return true end
  if string.find(lower, "unknown", 1, true) then return true end
  if string.find(lower, "missing", 1, true) then return true end
  if string.find(lower, "icon_missing", 1, true) then return true end
  if string.find(lower, "ability_1", 1, true) and string.find(lower, "empty", 1, true) then return true end
  if string.find(lower, "ability_none", 1, true) then return true end
  if string.find(lower, "crafting_empty", 1, true) then return true end
  -- Bare red "?" glyph path used on some console builds
  if lower == "?" or lower == "/esoui/art/icons/?" then return true end
  return false
end

-- Placeholder skill names we should not show to the user.
local function isPlaceholderName(name)
  if not name or name == "" then return true end
  name = tostring(name)
  if name == "?" or name == "—" or name == "-" then return true end
  if string.find(name, "^%[%d+%]$") then return true end           -- [7]
  if string.find(name, "^%[#%d+%]$") then return true end          -- [#7]
  if string.find(name, "^%[#?%d+%]$") then return true end
  if string.find(name, "^Ability %d+$") then return true end
  if string.find(name, "^Skill %d+$") then return true end
  if string.find(name, "^Slot %d+") then return true end
  return false
end

local function getAbilityIcon(abilityId)
  abilityId = tonumber(abilityId) or 0
  if abilityId <= 0 then return nil end
  if type(GetAbilityIcon) == "function" then
    local ok, tex = pcall(GetAbilityIcon, abilityId)
    if ok and tex and tex ~= "" and not isBadIconTex(tex) then return tex end
  end
  return nil
end

-- Prefer live hotbar slot texture (most reliable on console for bar display).
local function getSlotTextureFor(slot, cat)
  if type(GetSlotTexture) ~= "function" then return nil end
  local ok, tex
  if cat ~= nil then ok, tex = pcall(GetSlotTexture, slot, cat)
  else ok, tex = pcall(GetSlotTexture, slot) end
  if ok and tex and not isBadIconTex(tex) then return tex end
  return nil
end

-- Prefer session bar snapshot / skill table when GetAbilityIcon is empty/? on console.
local function resolveSkillIcon(session, abilityId, abilityName, slot, bar)
  abilityId = tonumber(abilityId) or 0
  local tex = getAbilityIcon(abilityId)
  if tex then return tex end
  local nameKey = abilityName and string.lower(tostring(abilityName)) or ""
  -- Direct slot snapshot (channel skills / console GetAbilityIcon misses).
  if session and type(session.slottedAbilityBySlot) == "table" and slot and bar then
    local entry = session.slottedAbilityBySlot[tostring(bar) .. ":" .. tostring(tonumber(slot) or 0)]
    if type(entry) == "table" then
      if entry.icon and not isBadIconTex(entry.icon) then return entry.icon end
      local eid = tonumber(entry.id) or 0
      if eid > 0 then
        local t = getAbilityIcon(eid)
        if t then return t end
      end
    end
  end
  -- Fuzzy-ish name match: exact, or either contains the other (morph/post labels).
  local function nameMatches(entryName)
    if not entryName or nameKey == "" then return false end
    local ek = string.lower(tostring(entryName))
    if ek == nameKey then return true end
    if #nameKey >= 4 and string.find(ek, nameKey, 1, true) then return true end
    if #ek >= 4 and string.find(nameKey, ek, 1, true) then return true end
    return false
  end
  if session and type(session.slottedAbilityBySlot) == "table" then
    for _, entry in pairs(session.slottedAbilityBySlot) do
      if type(entry) == "table" then
        local eid = tonumber(entry.id) or 0
        if eid > 0 and (eid == abilityId or nameMatches(entry.name)) then
          if entry.icon and not isBadIconTex(entry.icon) then return entry.icon end
          local t = getAbilityIcon(eid)
          if t then return t end
        end
      end
    end
  end
  if nameKey ~= "" and session and type(session.skills) == "table" then
    for id, sk in pairs(session.skills) do
      if type(sk) == "table" and nameMatches(sk.name) then
        local t = getAbilityIcon(tonumber(sk.id) or tonumber(id) or 0)
        if t then return t end
      end
    end
  end
  -- Live hotbar scan as last resort (console often resolves slot texture better).
  if abilityId > 0 and type(GetSlotBoundId) == "function" and type(GetSlotTexture) == "function" then
    local cats = {}
    if type(HOTBAR_CATEGORY_PRIMARY) ~= "nil" then cats[#cats + 1] = HOTBAR_CATEGORY_PRIMARY end
    if type(HOTBAR_CATEGORY_BACKUP) ~= "nil" then cats[#cats + 1] = HOTBAR_CATEGORY_BACKUP end
    if #cats == 0 then cats[1] = nil end
    for _, cat in ipairs(cats) do
      for slot = 3, 8 do
        local ok, sid
        if cat ~= nil then ok, sid = pcall(GetSlotBoundId, slot, cat)
        else ok, sid = pcall(GetSlotBoundId, slot) end
        if ok and tonumber(sid) == abilityId then
          local okT, tex2
          if cat ~= nil then okT, tex2 = pcall(GetSlotTexture, slot, cat)
          else okT, tex2 = pcall(GetSlotTexture, slot) end
          if okT and tex2 and not isBadIconTex(tex2) then return tex2 end
        end
      end
    end
  end
  return nil
end

local function getAbilityName(abilityId)
  abilityId = tonumber(abilityId) or 0
  if abilityId <= 0 then return "Unknown Skill" end
  if type(GetAbilityName) == "function" then
    local ok, name = pcall(GetAbilityName, abilityId)
    if ok and name and name ~= "" then
      if type(zo_strformat) == "function" then
        return zo_strformat("<<1>>", name)
      end
      return name
    end
  end
  return string.format("Skill %d", abilityId)
end

local function resolveSlotIcon(abilityId)
  abilityId = tonumber(abilityId) or 0
  if abilityId <= 0 then return nil end
  local tex = getAbilityIcon(abilityId)
  if tex then return tex end
  return resolveSkillIcon(nil, abilityId, nil)
end

---------------------------------------------------------------------
-- History bridge (via R public API — no SV nesting hacks)
---------------------------------------------------------------------
local function historyCount()
  if type(R.GetMenuHistoryCount) == "function" then
    local ok, n = pcall(function() return R:GetMenuHistoryCount() end)
    if ok then return tonumber(n) or 0 end
  end
  return 0
end

local function historyAt(offset)
  if type(R.GetMenuHistoryAt) == "function" then
    local ok, s = pcall(function() return R:GetMenuHistoryAt(offset) end)
    if ok and type(s) == "table" then return s end
  end
  return nil
end

local function bucketMs()
  if type(R.GetMenuBucketMs) == "function" then
    local ok, n = pcall(function() return R:GetMenuBucketMs() end)
    if ok and tonumber(n) and tonumber(n) > 0 then return tonumber(n) end
  end
  return 2000
end

local function clampHistoryOffset(offset, count)
  offset = tonumber(offset) or 0
  count = tonumber(count) or 0
  if count <= 0 then return 0 end
  if offset < 0 then offset = 0 end
  if offset > count - 1 then offset = count - 1 end
  return offset
end

local function sessionAvgDps(session)
  local dur = tonumber(session and session.durationMs) or 0
  if dur <= 0 then return 0 end
  return (tonumber(session.totalDamage) or 0) / (dur / 1000)
end

local function sessionPeakDps(session)
  local bms = bucketMs()
  local peak = 0
  if session and type(session.buckets) == "table" then
    for _, b in pairs(session.buckets) do
      if type(b) == "table" then
        local dps = (tonumber(b.dmg) or 0) / (bms / 1000)
        if dps > peak then peak = dps end
      end
    end
  end
  if peak <= 0 then peak = tonumber(session and session.maxHit) or 0 end
  return peak
end

local function sessionCritPct(session)
  local hits = tonumber(session and session.hitCount) or 0
  if hits <= 0 then return 0 end
  return (tonumber(session.critCount) or 0) / hits
end

local function getWeaveSuccessRatio(session)
  if not session or type(session.weave) ~= "table" then return 0 end
  local w = session.weave
  local good = tonumber(w.onTimeCount) or 0
  local late = tonumber(w.lateCount) or 0
  local missed = tonumber(w.missedCount) or 0
  local tooFast = tonumber(w.tooFastCount) or 0
  local total = good + late + missed + tooFast
  if total <= 0 then return 0 end
  return math.max(0, math.min(1, (good + late) / total))
end

local function sessionLaHits(session)
  local w = session and session.weave
  if type(w) ~= "table" then return 0 end
  return tonumber(w.laCount) or tonumber(w.laPressCount) or tonumber(w.laHits) or 0
end

local function formatSessionTimestampShort(session)
  local ts = session and (session.completedAt or session.endEpoch or session.timestamp)
  ts = tonumber(ts)
  if not ts or ts <= 0 then return "-" end
  return os.date("%m/%d %H:%M", ts)
end

local function getSkillBar(session, abilityId)
  if not session or type(session.slottedAbilityBar) ~= "table" then return nil end
  abilityId = tonumber(abilityId) or 0
  if abilityId <= 0 then return nil end
  local bar = session.slottedAbilityBar[tostring(abilityId)] or session.slottedAbilityBar[abilityId]
  if bar == "Front" or bar == "Back" then return bar end
  return nil
end

local function barChipLabel(bar)
  if bar == "Front" then return "F" end
  if bar == "Back" then return "B" end
  return ""
end

local function barChipColor(bar)
  if bar == "Front" then return THEME.frontR, THEME.frontG, THEME.frontB, 1 end
  if bar == "Back" then return THEME.backR, THEME.backG, THEME.backB, 1 end
  return THEME.mutedR, THEME.mutedG, THEME.mutedB, 0.4
end

-- F green · B blue · U gold · S amber · E bold purple
local function sourceChipColor(chip, bar)
  if chip == "U" then return 0.98, 0.82, 0.22, 1 end
  if chip == "E" then return 0.78, 0.38, 0.95, 1 end
  if chip == "S" then return 0.95, 0.62, 0.22, 1 end
  if chip == "LA" then return 0.65, 0.88, 1.0, 1 end
  return barChipColor(bar)
end

-- #1 = newest fight (offset 0), #2 = one older, … oldest is highest number.
local function fightNumberFromOffset(offset, count)
  offset = tonumber(offset) or 0
  count = tonumber(count) or 0
  local n = offset + 1
  if count > 0 and n > count then n = count end
  if n < 1 then n = 1 end
  return n
end

-- Ultimate: API cost, or snapshotted on slot 8 of Front/Back (FB/BB ult).
local function isUltimateAbility(abilityId, session, abilityName)
  abilityId = tonumber(abilityId) or 0
  if abilityId <= 0 then return false end
  if type(GetAbilityUltimateCost) == "function" then
    local ok, cost = pcall(GetAbilityUltimateCost, abilityId)
    if ok and (tonumber(cost) or 0) > 0 then return true end
  end
  if type(IsAbilityUltimateAbility) == "function" then
    local ok, ult = pcall(IsAbilityUltimateAbility, abilityId)
    if ok and ult then return true end
  end
  -- Scribed / morph IDs sometimes report 0 cost — match ult slots on either bar
  if session and type(session.slottedAbilityBySlot) == "table" then
    for _, bar in ipairs({ "Front", "Back" }) do
      local entry = session.slottedAbilityBySlot[bar .. ":8"]
      if type(entry) == "table" and (tonumber(entry.id) or 0) == abilityId then
        return true
      end
    end
  end
  -- Name fallback for known ult patterns (Herald Eye morphs etc.) when API silent
  local nlow = string.lower(tostring(abilityName or ""))
  if nlow == "" and session and type(session.skills) == "table" then
    local sk = session.skills[abilityId]
    if type(sk) == "table" then nlow = string.lower(tostring(sk.name or "")) end
  end
  if nlow ~= "" then
    if string.find(nlow, "the languid eye", 1, true) or string.find(nlow, "the scourging eye", 1, true)
        or string.find(nlow, "the soulburst", 1, true) or string.find(nlow, "soulburst", 1, true)
        or string.find(nlow, "ultimate", 1, true) then
      return true
    end
    -- "Sovereign Eye" / similar morph naming
    if string.find(nlow, " eye", 1, true) and (
        string.find(nlow, "languid", 1, true) or string.find(nlow, "scourging", 1, true)
        or string.find(nlow, "sovereign", 1, true) or string.find(nlow, "devouring", 1, true)
      ) then
      return true
    end
  end
  return false
end

-- Match combat ability name to a snapshotted bar skill (DoT ticks often use a
-- different abilityId than the slotted cast — e.g. Stampede ticks).
local function barFromSlottedName(session, name)
  local nlow = string.lower(tostring(name or ""))
  if nlow == "" or not session then return nil end
  if type(session.slottedAbilityBarByName) == "table" then
    local b = session.slottedAbilityBarByName[nlow]
    if b == "Front" or b == "Back" then return b end
  end
  if type(session.slottedAbilityBySlot) == "table" then
    for _, entry in pairs(session.slottedAbilityBySlot) do
      if type(entry) == "table" and entry.name then
        local en = string.lower(tostring(entry.name))
        if en ~= "" and (en == nlow or string.find(nlow, en, 1, true) or string.find(en, nlow, 1, true)) then
          -- Infer bar from which key held this entry when possible
          break
        end
      end
    end
    -- Prefer explicit Front:/Back: keys
    for _, barLabel in ipairs({ "Front", "Back" }) do
      for slot = 3, 8 do
        local entry = session.slottedAbilityBySlot[barLabel .. ":" .. tostring(slot)]
        if type(entry) == "table" and entry.name then
          local en = string.lower(tostring(entry.name))
          if en ~= "" and (en == nlow or string.find(nlow, en, 1, true) or string.find(en, nlow, 1, true)) then
            return barLabel
          end
        end
      end
    end
  end
  if type(session.slottedAbilityNames) == "table" then
    for slottedName, _ in pairs(session.slottedAbilityNames) do
      local en = string.lower(tostring(slottedName))
      if en ~= "" and (en == nlow or string.find(nlow, en, 1, true) or string.find(en, nlow, 1, true)) then
        return "Front" -- bar unknown; still primary Skill for left panel
      end
    end
  end
  return nil
end

-- Classify: LA → Ultimate → bar Skill → Set → Effect.
-- Left Skills panel = rotation skills (F/B), LA/HA, Ult — like the old single list.
local function classifyDamageSource(session, abilityId, name, bar)
  abilityId = tonumber(abilityId) or 0
  local nlow = name and string.lower(tostring(name)) or ""
  if nlow ~= "" and string.find(nlow, "light attack", 1, true) then
    return "Light attack", "LA"
  end
  if nlow ~= "" and string.find(nlow, "heavy attack", 1, true) then
    return "Heavy attack", "HA"
  end
  if isUltimateAbility(abilityId, session, name) then
    return "Ultimate", "U"
  end
  if bar == "Front" or bar == "Back" then
    return "Skill", barChipLabel(bar)
  end
  if session and type(session.slottedAbilityIds) == "table" and abilityId > 0
      and session.slottedAbilityIds[abilityId] then
    local b = getSkillBar(session, abilityId)
    return "Skill", barChipLabel(b)
  end
  -- DoT / morph tick id ≠ slotted cast id — still a bar skill if name matches
  local nameBar = barFromSlottedName(session, name)
  if nameBar then
    return "Skill", barChipLabel(nameBar)
  end
  if session and type(session.sets) == "table" and nlow ~= "" then
    for _, ps in pairs(session.sets) do
      if type(ps) == "table" and ps.name then
        local sn = string.lower(tostring(ps.name))
        if sn ~= "" and (string.find(nlow, sn, 1, true) or string.find(sn, nlow, 1, true)) then
          return "Set proc", "S"
        end
      end
    end
  end
  return "Effect", "E"
end

local function buffTierLabel(uptime)
  uptime = tonumber(uptime) or 0
  if uptime >= 0.95 then return "Always-on" end
  if uptime >= 0.50 then return "Sustained" end
  return "Situational"
end

-- Full-fight damage contribution (Skill / Ultimate / LA / Set / Effect).
local function buildDamageContribution(session)
  local buckets = { skill = 0, ultimate = 0, light = 0, set = 0, effect = 0 }
  local total = tonumber(session and session.totalDamage) or 0
  if session and type(session.skills) == "table" then
    for id, sk in pairs(session.skills) do
      if type(sk) == "table" then
        local dmg = tonumber(sk.dmg) or 0
        if dmg > 0 then
          local abilityId = tonumber(sk.id) or tonumber(id) or 0
          local name = sk.name or getAbilityName(abilityId)
          local bar = getSkillBar(session, abilityId)
          local source = classifyDamageSource(session, abilityId, name, bar)
          if source == "Ultimate" then buckets.ultimate = buckets.ultimate + dmg
          elseif source == "Light attack" then buckets.light = buckets.light + dmg
          elseif source == "Set proc" then buckets.set = buckets.set + dmg
          elseif source == "Skill" then buckets.skill = buckets.skill + dmg
          else buckets.effect = buckets.effect + dmg end
        end
      end
    end
  end
  local sum = buckets.skill + buckets.ultimate + buckets.light + buckets.set + buckets.effect
  if total <= 0 then total = sum end
  local function part(key, label, chip)
    local dmg = buckets[key] or 0
    local pct = total > 0 and (dmg / total) or 0
    return {
      key = key, label = label, chip = chip,
      dmg = dmg, dmgTxt = fmtInt(dmg), pct = pct, pctTxt = fmtPct(pct),
    }
  end
  return {
    total = total,
    parts = {
      part("skill", "Skill", "F/B"),
      part("ultimate", "Ultimate", "U"),
      part("light", "Light attack", "LA"),
      part("set", "Set proc", "S"),
      part("effect", "Effect", "E"),
    },
    buckets = buckets,
  }
end

---------------------------------------------------------------------
-- View models (menu-only; do not refactor overlay)
---------------------------------------------------------------------
local function damageTypeLabel(damageType)
  damageType = tonumber(damageType)
  if not damageType then return nil end
  local map = {
    [DAMAGE_TYPE_PHYSICAL or -1] = "Physical",
    [DAMAGE_TYPE_FIRE or -1] = "Flame",
    [DAMAGE_TYPE_SHOCK or -1] = "Shock",
    [DAMAGE_TYPE_COLD or -1] = "Frost",
    [DAMAGE_TYPE_OBLIVION or -1] = "Oblivion",
    [DAMAGE_TYPE_GENERIC or -1] = "Generic",
    [DAMAGE_TYPE_MAGIC or -1] = "Magic",
    [DAMAGE_TYPE_DISEASE or -1] = "Disease",
    [DAMAGE_TYPE_POISON or -1] = "Poison",
    [DAMAGE_TYPE_BLEED or -1] = "Bleed",
  }
  if map[damageType] then return map[damageType] end
  if type(GetString) == "function" then
    local ok, s = pcall(GetString, _G["SI_DAMAGETYPE" .. tostring(damageType)])
    if ok and type(s) == "string" and s ~= "" then return s end
  end
  return nil
end

local function dominantDamageTypeLabel(damageTypes)
  if type(damageTypes) ~= "table" then return nil end
  local best, bestD = nil, 0
  for dt, dmg in pairs(damageTypes) do
    dmg = tonumber(dmg) or 0
    if dmg > bestD then
      bestD = dmg
      best = damageTypeLabel(dt) or ("type " .. tostring(dt))
    end
  end
  return best
end

local function resolveAoeTag(session, sk, abilityId)
  -- Prefer main-module capture (unique targets + radius)
  if R and type(R.SkillAoeLabel) == "function" then
    local ok, tag = pcall(R.SkillAoeLabel, sk, abilityId)
    if ok and type(tag) == "string" and tag ~= "" then return tag end
  end
  local n = tonumber(sk and sk.uniqueTargetCount) or 0
  if n >= 2 then return "AoE" end
  if n == 1 then return "ST" end
  return "?"
end

local function buildTopSkillRows(session, maxRows)
  maxRows = tonumber(maxRows) or LIST_MAX_ROWS
  local rows = {}
  if not session or type(session.skills) ~= "table" then return rows end
  local totalDamage = tonumber(session.totalDamage) or 0
  local dur = tonumber(session.durationMs) or 0
  local skillArr = {}
  for id, sk in pairs(session.skills) do
    if type(sk) == "table" then
      local abilityId = tonumber(sk.id) or tonumber(id) or 0
      local dmg = tonumber(sk.dmg) or 0
      if dmg > 0 then
      table.insert(skillArr, {
        id = abilityId,
        name = sk.name,
        dmg = dmg,
        hits = tonumber(sk.hits) or 0,
        crit = tonumber(sk.crit) or 0,
        max = tonumber(sk.max) or 0,
        dot = tonumber(sk.dot) or 0,
        damageTypes = sk.damageTypes,
        uniqueTargetCount = sk.uniqueTargetCount,
        uniqueTargets = sk.uniqueTargets,
      })
      end
    end
  end
  table.sort(skillArr, function(a, b) return (a.dmg or 0) > (b.dmg or 0) end)
  for i = 1, math.min(maxRows, #skillArr) do
    local sk = skillArr[i]
    local dmg = sk.dmg or 0
    local hits = sk.hits or 0
    local share = totalDamage > 0 and (dmg / totalDamage) or 0
    local dps = dur > 0 and (dmg / (dur / 1000)) or 0
    local critPct = hits > 0 and ((sk.crit or 0) / hits) or 0
    local avgHit = hits > 0 and (dmg / hits) or 0
    local dotp = dmg > 0 and ((sk.dot or 0) / dmg) or 0
    local kind = (dotp > 0.95) and "DoT" or (dotp < 0.05) and "Direct" or "Mixed"
    local abilityId = sk.id or 0
    local name = sk.name
    if not name or name == "" then name = getAbilityName(abilityId) end
    local bar = getSkillBar(session, abilityId)
    local source, sourceChip = classifyDamageSource(session, abilityId, name, bar)
    -- Dominant combat damage type (Physical / Magic / Flame / …) — not "melee"
    local dtype = dominantDamageTypeLabel(sk.damageTypes)
    local aoeTag = resolveAoeTag(session, sk, abilityId)
    local kindTxt = kind
    if dtype then kindTxt = string.format("%s · %s", kind, dtype) end
    if aoeTag and aoeTag ~= "?" then kindTxt = kindTxt .. " · " .. aoeTag end
    if source == "Ultimate" then kindTxt = kindTxt .. " · Ult" end
    local isPrimary = (source == "Skill" or source == "Ultimate" or source == "Light attack"
      or source == "Heavy attack" or sourceChip == "F" or sourceChip == "B"
      or sourceChip == "U" or sourceChip == "LA" or sourceChip == "HA")
    rows[i] = {
      name = name,
      id = abilityId,
      abilityId = abilityId,
      sub = string.format(
        "%s · %s share · %s DPS · %s hits · crit %s · %s",
        source, fmtPct(share), fmtDps(dps), tostring(hits), fmtPct(critPct), kindTxt
      ),
      icon = resolveSkillIcon(session, abilityId, name),
      bar = bar,
      source = source,
      sourceChip = sourceChip,
      isUltimate = (source == "Ultimate"),
      isPrimary = isPrimary,
      aoeTag = aoeTag,
      share = share,
      -- dense Damage table columns
      amountTxt = fmtInt(dmg),
      hitsTxt = tostring(hits),
      avgTxt = fmtInt(avgHit),
      shareTxt = fmtPct(share),
      critTxt = fmtPct(critPct),
      kindTxt = kindTxt,
      dpsTxt = fmtDps(dps),
      maxTxt = fmtInt(sk.max),
    }
  end
  -- Same display name, different ability IDs = separate combat components (scribed scripts,
  -- Crystal Fragments proc vs cast, Stampede hit vs leap). Tag Type with the id so they
  -- are not mistaken for duplicate rows.
  do
    local nameCount = {}
    for i = 1, #rows do
      local k = string.lower(tostring(rows[i].name or ""))
      if k ~= "" then nameCount[k] = (nameCount[k] or 0) + 1 end
    end
    for i = 1, #rows do
      local k = string.lower(tostring(rows[i].name or ""))
      local id = tonumber(rows[i].id) or 0
      if k ~= "" and (nameCount[k] or 0) > 1 and id > 0 then
        rows[i].kindTxt = tostring(rows[i].kindTxt or "") .. " · " .. tostring(id)
      end
    end
  end
  return rows
end

-- Mundus names + buff source/effect helpers (must stay above buffRowFromEntry)
local MUNDUS_NAMES = {
  "The Apprentice", "The Atronach", "The Lady", "The Lord", "The Lover",
  "The Mage", "The Ritual", "The Serpent", "The Shadow", "The Steed",
  "The Thief", "The Tower", "The Warrior",
}

-- Strict mundus only. Do NOT substring-match "mage" (that hits "magicka" on food buffs
-- and minted a new Build ID when food dropped). In-game buff is "Boon: The Thief".
local function canonicalMundusName(raw)
  if raw == nil then return nil end
  local plain = stripColorLocal(tostring(raw))
  if type(zo_strformat) == "function" then
    local ok, fmt = pcall(zo_strformat, "<<1>>", plain)
    if ok and type(fmt) == "string" and fmt ~= "" then plain = fmt end
  end
  local low = string.lower(plain)
  low = low:gsub("^%s+", ""):gsub("%s+$", "")
  if low == "" then return nil end
  low = low:gsub("^boon:%s*", "")
  for i = 1, #MUNDUS_NAMES do
    local mundus = MUNDUS_NAMES[i]
    local m = string.lower(mundus)
    if low == m then return mundus end
  end
  for i = 1, #MUNDUS_NAMES do
    local mundus = MUNDUS_NAMES[i]
    local m = string.lower(mundus)
    if #low >= #m and string.sub(low, 1, #m) == m then
      local rest = string.sub(low, #m + 1)
      if rest == "" or string.find(rest, "^[%s%p]") then
        if not string.find(rest, "magicka", 1, true)
            and not string.find(rest, "stamina", 1, true)
            and not string.find(rest, "food", 1, true)
            and not string.find(rest, "drink", 1, true) then
          return mundus
        end
      end
    end
  end
  return nil
end

-- Major/Minor + common combat statuses (hand-curated; unknown → fallback tag)
local BUFF_EFFECT_HINTS = {
  ["major sorcery"] = { tag = "Spell Dmg", detail = "+20% Spell Damage" },
  ["minor sorcery"] = { tag = "Spell Dmg", detail = "+10% Spell Damage" },
  ["major brutality"] = { tag = "Weapon Dmg", detail = "+20% Weapon Damage" },
  ["minor brutality"] = { tag = "Weapon Dmg", detail = "+10% Weapon Damage" },
  ["major prophecy"] = { tag = "Spell Crit", detail = "+12% Spell Critical" },
  ["minor prophecy"] = { tag = "Spell Crit", detail = "+6% Spell Critical" },
  ["major savagery"] = { tag = "Wpn Crit", detail = "+12% Weapon Critical" },
  ["minor savagery"] = { tag = "Wpn Crit", detail = "+6% Weapon Critical" },
  ["major force"] = { tag = "Crit Dmg", detail = "+20% Critical Damage" },
  ["minor force"] = { tag = "Crit Dmg", detail = "+10% Critical Damage" },
  ["major breach"] = { tag = "Pen (debuff)", detail = "−5948 enemy resist" },
  ["minor breach"] = { tag = "Pen (debuff)", detail = "−2974 enemy resist" },
  ["major courage"] = { tag = "Power", detail = "+430 Wpn/Spell Damage" },
  ["minor courage"] = { tag = "Power", detail = "+215 Wpn/Spell Damage" },
  ["major slayer"] = { tag = "Dmg done", detail = "+10% damage done" },
  ["minor slayer"] = { tag = "Dmg done", detail = "+5% damage done" },
  ["major berserk"] = { tag = "Dmg done", detail = "+10% damage done" },
  ["minor berserk"] = { tag = "Dmg done", detail = "+5% damage done" },
  ["major resolve"] = { tag = "Resist", detail = "+5948 armor" },
  ["minor resolve"] = { tag = "Resist", detail = "+2974 armor" },
  ["major fortitude"] = { tag = "HP recovery", detail = "+30% Health Recovery" },
  ["minor fortitude"] = { tag = "HP recovery", detail = "+15% Health Recovery" },
  ["major intellect"] = { tag = "Mag recovery", detail = "+30% Magicka Recovery" },
  ["major endurance"] = { tag = "Stam recovery", detail = "+30% Stamina Recovery" },
  ["minor intellect"] = { tag = "Mag recovery", detail = "+15% Magicka Recovery" },
  ["minor endurance"] = { tag = "Stam recovery", detail = "+15% Stamina Recovery" },
  ["major expedition"] = { tag = "Speed", detail = "+30% Movement Speed" },
  ["minor expedition"] = { tag = "Speed", detail = "+15% Movement Speed" },
  ["major protection"] = { tag = "Mitigation", detail = "−10% damage taken" },
  ["minor protection"] = { tag = "Mitigation", detail = "−5% damage taken" },
  ["major mending"] = { tag = "Healing", detail = "+16% healing done" },
  ["minor mending"] = { tag = "Healing", detail = "+8% healing done" },
  ["major vitality"] = { tag = "Healing taken", detail = "+12% healing taken" },
  ["minor vitality"] = { tag = "Healing taken", detail = "+6% healing taken" },
  ["major brutality and sorcery"] = { tag = "Power", detail = "+20% Wpn & Spell Dmg" },
  ["minor brutality and sorcery"] = { tag = "Power", detail = "+10% Wpn & Spell Dmg" },
  ["major savagery and prophecy"] = { tag = "Crit", detail = "+12% Wpn & Spell Crit" },
  ["minor savagery and prophecy"] = { tag = "Crit", detail = "+6% Wpn & Spell Crit" },
  ["major vulnerability"] = { tag = "Dmg taken", detail = "+10% dmg taken (enemy)" },
  ["minor vulnerability"] = { tag = "Dmg taken", detail = "+5% dmg taken (enemy)" },
  ["major evasion"] = { tag = "Dodge", detail = "+20% Dodge Chance" },
  ["minor evasion"] = { tag = "Dodge", detail = "+10% Dodge Chance" },
  ["major heroism"] = { tag = "Ult gen", detail = "+3 Ult/s" },
  ["minor heroism"] = { tag = "Ult gen", detail = "+1.5 Ult/s" },
  ["major toughness"] = { tag = "Max HP", detail = "+10% Max Health" },
  ["minor toughness"] = { tag = "Max HP", detail = "+5% Max Health" },
  ["off balance"] = { tag = "CC", detail = "Off Balance window" },
  ["off-balance"] = { tag = "CC", detail = "Off Balance window" },
  ["concussed"] = { tag = "Status", detail = "Concussed status" },
  ["sundered"] = { tag = "Status", detail = "Sundered status" },
  ["burning"] = { tag = "Status", detail = "Burning DoT" },
  ["poisoned"] = { tag = "Status", detail = "Poisoned DoT" },
  ["hemorrhaging"] = { tag = "Status", detail = "Hemorrhage DoT" },
  ["chilled"] = { tag = "Status", detail = "Chilled status" },
  ["bound armaments"] = { tag = "Skill", detail = "Bound weapon stacks" },
  ["crystal fragments"] = { tag = "Proc", detail = "Instant Crystal Blast" },
  ["power of the light"] = { tag = "Debuff", detail = "Exploding DoT mark" },
  ["barbed trap"] = { tag = "Crit Dmg", detail = "Minor Force source" },
  ["lightweight beast trap"] = { tag = "Crit Dmg", detail = "Minor Force source" },
  ["guarded"] = { tag = "Support", detail = "Guard link" },
  ["weapon skill"] = { tag = "Passive", detail = "Weapon skill passive" },
  ["on-hit"] = { tag = "Proc", detail = "On-hit effect" },
  ["3-hit"] = { tag = "Proc", detail = "3-hit / weave proc" },
}

-- Key self-buffs to surface on Dashboard uptime strip (standard Major/Minor names)
local KEY_SELF_BUFF_KEYS = {
  { key = "major force", label = "Major Force" },
  { key = "minor force", label = "Minor Force" },
  { key = "major brutality", label = "Major Brutality" },
  { key = "major sorcery", label = "Major Sorcery" },
  { key = "major savagery", label = "Major Savagery" },
  { key = "major prophecy", label = "Major Prophecy" },
  { key = "major slayer", label = "Major Slayer" },
  { key = "major berserk", label = "Major Berserk" },
  { key = "minor berserk", label = "Minor Berserk" },
  { key = "major courage", label = "Major Courage" },
}

local PEN_TARGET_LIGHT = 18200 -- common light-armor parse / dummy target

---------------------------------------------------------------------
-- Content profiles (trial-prep default) + confidence labels
-- Outcomes numbers never change with profile — only interpretation.
---------------------------------------------------------------------
local CONFIDENCE = {
  OBSERVED = "Observed",
  CALCULATED = "Calculated",
  ESTIMATED = "Estimated",
  INSUFFICIENT = "Insufficient Data",
}

local CONTENT_PROFILES = {
  trial_prep_dummy = {
    id = "trial_prep_dummy",
    label = "Trial-prep dummy",
    shortLabel = "Trial-prep",
    bossResist = 18200,
    assumeMajorBreach = true,
    assumeMinorBreach = false,
    assumeCrusher = true,
    critDamageCeiling = 1.25, -- 125%
    assumeMajorForce = true,
    assumeMinorForce = true,
    note = "Assumes organized-group buffs/debuffs. DPS numbers are unchanged.",
  },
  pure_dummy = {
    id = "pure_dummy",
    label = "Pure dummy",
    shortLabel = "Pure dummy",
    bossResist = 18200,
    assumeMajorBreach = false,
    assumeMinorBreach = false,
    assumeCrusher = false,
    critDamageCeiling = 1.25,
    assumeMajorForce = false,
    assumeMinorForce = false,
    note = "Personal sheet only — no assumed group buffs.",
  },
}

local DEFAULT_CONTENT_PROFILE_ID = "trial_prep_dummy"

local function getActiveContentProfile()
  local id = DEFAULT_CONTENT_PROFILE_ID
  if R and R.SV and type(R.SV.settings) == "table" and R.SV.settings.contentProfile then
    id = tostring(R.SV.settings.contentProfile)
  end
  return CONTENT_PROFILES[id] or CONTENT_PROFILES[DEFAULT_CONTENT_PROFILE_ID]
end

local function confidenceChip(confidence)
  confidence = tostring(confidence or CONFIDENCE.ESTIMATED)
  if confidence == CONFIDENCE.OBSERVED then
    return "|c66FF88[" .. confidence .. "]|r"
  elseif confidence == CONFIDENCE.CALCULATED then
    return "|c66AAFF[" .. confidence .. "]|r"
  elseif confidence == CONFIDENCE.INSUFFICIENT then
    return "|c888888[" .. confidence .. "]|r"
  end
  return "|cFFCC66[" .. confidence .. "]|r"
end

local function formatProfileBadge(profile)
  profile = profile or getActiveContentProfile()
  return string.format("Profile: %s", profile.label or profile.shortLabel or "Trial-prep dummy")
end

-- Prefer readable names; only trim when over max (no esoteric abbreviations).
local function displayName(name, maxLen)
  name = tostring(name or "?")
  maxLen = tonumber(maxLen) or 48
  if #name <= maxLen then return name end
  return string.sub(name, 1, maxLen - 1) .. "..."
end

-- Strip |cRRGGBB / |r before truncating. A dangling |c after string.sub makes
-- ESO hide the entire label (Build & Sets row 1 Warfare star went blank).
local function stripColorMarkup(s)
  s = tostring(s or "")
  s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
  s = s:gsub("|C%x%x%x%x%x%x%x%x", "")
  s = s:gsub("|c%x%x%x%x%x%x", "")
  s = s:gsub("|C%x%x%x%x%x%x", "")
  s = s:gsub("|r", "")
  s = s:gsub("|R", "")
  return s
end

local function displayNamePlain(name, maxLen)
  return displayName(stripColorMarkup(name), maxLen)
end

-- Show ability/champion skill ids as "Name · id 12345" so users know it is an id
local function formatAbilityDisplay(name, abilityId, maxLen)
  name = tostring(name or "?")
  abilityId = tonumber(abilityId) or 0
  local s = name
  if abilityId > 0 then
    s = string.format("%s  ·  id %d", name, abilityId)
  end
  return displayName(s, maxLen or 56)
end

local function fitBadgeColor(fitKey)
  if fitKey == "strong" then return 0.45, 0.92, 0.55, 1 end
  if fitKey == "soft" then return 0.90, 0.52, 0.38, 1 end
  if fitKey == "na" then return 0.55, 0.62, 0.72, 1 end
  if fitKey == "surv" then return 0.36, 0.61, 0.84, 1 end
  return 0.95, 0.82, 0.40, 1 -- ok
end

local function buffEffectHint(name)
  local low = string.lower(tostring(name or ""))
  if low == "" then return nil end
  -- Longer keys first so "major brutality and sorcery" beats "major brutality"
  local bestKey, bestHint, bestLen = nil, nil, -1
  for key, hint in pairs(BUFF_EFFECT_HINTS) do
    if string.find(low, key, 1, true) and #key > bestLen then
      bestKey, bestHint, bestLen = key, hint, #key
    end
  end
  if bestHint then return bestHint end
  return nil
end

local function buffEffectDisplay(name, sourceTxt)
  local hint = buffEffectHint(name)
  if hint and hint.detail then return hint.detail, hint.tag or "" end
  local src = string.lower(tostring(sourceTxt or ""))
  if string.find(src, "set", 1, true) then return "Set effect", "Set" end
  if string.find(src, "food", 1, true) or string.find(src, "drink", 1, true)
      or string.find(src, "consumable", 1, true) then
    return "Food/Drink", "Consumable"
  end
  if string.find(src, "potion", 1, true) then return "Potion", "Consumable" end
  if string.find(src, "mundus", 1, true) then return "Mundus", "Mundus" end
  if string.find(src, "skill", 1, true) then return "Skill effect", "Skill" end
  return "—", ""
end

local function classifyBuffSourceDetailed(session, b)
  if not b then return "Unknown", "Unknown" end
  local abilityId = tonumber(b.id) or 0
  local name = tostring(b.name or "")
  local nlow = string.lower(name)

  for _, mundus in ipairs(MUNDUS_NAMES) do
    if nlow == string.lower(mundus) or string.find(nlow, string.lower(mundus), 1, true) then
      return "Mundus", "Mundus"
    end
  end
  if b.fromGroup then return "Group", "Group" end
  if b.fromDummy then return "Dummy", "Trial dummy" end
  if b.fromExternal then return "External", "Dummy/ally" end
  if b.fromPet then return "Pet", "Your pet" end
  if string.find(nlow, "food", 1, true) or string.find(nlow, "drink", 1, true)
      or string.find(nlow, "meal", 1, true) or string.find(nlow, "gourmet", 1, true) then
    return "Consumable", "Food/Drink"
  end
  -- Common dummy-granted power buffs (when sourceType missing)
  if string.find(nlow, "major courage", 1, true) or string.find(nlow, "minor courage", 1, true)
      or string.find(nlow, "major slayer", 1, true) or string.find(nlow, "major berserk", 1, true) then
    if not b.fromSelf then return "Dummy", "Trial dummy / external" end
  end
  if string.find(nlow, "potion", 1, true) or string.find(nlow, "essence of", 1, true) then
    return "Consumable", "Potion"
  end
  if abilityId > 0 and session and type(session.slottedAbilityIds) == "table"
      and session.slottedAbilityIds[abilityId] then
    return "Skill", "Your skill"
  end
  if session and type(session.sets) == "table" then
    for _, ps in pairs(session.sets) do
      if type(ps) == "table" and ps.name then
        local sn = string.lower(tostring(ps.name))
        if sn ~= "" and (string.find(nlow, sn, 1, true) or string.find(sn, nlow, 1, true)) then
          return "Set", "Set: " .. tostring(ps.name)
        end
      end
    end
  end
  if session and type(session.equippedSets) == "table" then
    for _, setName in ipairs(session.equippedSets) do
      local sn = string.lower(tostring(setName))
      if sn ~= "" and string.find(nlow, sn, 1, true) then
        return "Set", "Set: " .. tostring(setName)
      end
    end
  end
  if session and type(session.equippedSetMap) == "table" then
    local key = nlow:gsub("%s+", " ")
    if session.equippedSetMap[key] then return "Set", "Set bonus" end
  end
  if abilityId > 0 and session and type(session.skills) == "table" and session.skills[abilityId] then
    return "Self", "Your ability"
  end
  if b.fromSelf then return "Self", "You" end
  if string.find(nlow, "champion", 1, true) then return "CP", "Champion" end
  return "Other", "Other/unknown"
end

local function buffRowFromEntry(session, b, dur)
  local activeMs = tonumber(b.activeMs) or 0
  local uptime = dur > 0 and (activeMs / dur) or 0
  local abilityId = tonumber(b.id) or 0
  local tier = buffTierLabel(uptime)
  local sourceKey, sourceDetail = classifyBuffSourceDetailed(session, b)
  local effectTxt, effectTag = buffEffectDisplay(b.name, sourceKey)
  local sourceShort = sourceKey or "Other"
  -- Compact source for table column; detail for sub/tooltip-ish
  return {
    name = b.name or "?",
    id = abilityId,
    sub = string.format(
      "%s · %s up · %s%s",
      sourceDetail or sourceShort,
      fmtPct(uptime),
      tier,
      (effectTxt ~= "" and effectTxt ~= "—" and (" · " .. effectTxt) or "")
    ),
    icon = resolveSkillIcon(session, abilityId, b.name),
    bar = getSkillBar(session, abilityId),
    share = uptime,
    sourceTxt = sourceShort,
    sourceDetail = sourceDetail or sourceShort,
    effectTxt = effectTxt,
    effectTag = effectTag or "",
    uptimeTxt = fmtPct(uptime),
    activeTxt = fmtDur(activeMs),
    appsTxt = tostring(tonumber(b.applied or 0)),
    tierTxt = tier,
    uptime = uptime,
  }
end

-- Split buffs by tier for hybrid layout (Always-on main, Sustained+Situational side).
local function buildBuffTierLists(session)
  local always, sust, sit = {}, {}, {}
  if not session or type(session.buffs) ~= "table" then
    return always, sust, sit, 0
  end
  local dur = tonumber(session.durationMs) or 0
  local arr = {}
  for _, b in pairs(session.buffs) do
    if type(b) == "table" then arr[#arr + 1] = b end
  end
  table.sort(arr, function(a, b) return (tonumber(a.activeMs) or 0) > (tonumber(b.activeMs) or 0) end)
  for _, b in ipairs(arr) do
    local row = buffRowFromEntry(session, b, dur)
    if row.tierTxt == "Always-on" then always[#always + 1] = row
    elseif row.tierTxt == "Sustained" then sust[#sust + 1] = row
    else sit[#sit + 1] = row end
  end
  return always, sust, sit, #arr
end

local function buildBuffModelRows(session, maxRows)
  maxRows = tonumber(maxRows) or BUFF_MAIN_ROWS
  local always = buildBuffTierLists(session)
  local rows = {}
  for i = 1, math.min(maxRows, #always) do rows[i] = always[i] end
  return rows
end

-- Target debuffs / status applied during the parse (Off Balance, Concussed, …)
local function buildTargetDebuffRows(session, maxRows)
  maxRows = tonumber(maxRows) or BUFF_SIDE_ROWS
  local rows = {}
  if not session or type(session.targetDebuffs) ~= "table" then return rows end
  local dur = tonumber(session.durationMs) or 0
  local arr = {}
  for _, d in pairs(session.targetDebuffs) do
    if type(d) == "table" then arr[#arr + 1] = d end
  end
  table.sort(arr, function(a, b)
    local aa, bb = tonumber(a.applied) or 0, tonumber(b.applied) or 0
    if aa ~= bb then return aa > bb end
    return (tonumber(a.activeMs) or 0) > (tonumber(b.activeMs) or 0)
  end)
  for i = 1, math.min(maxRows, #arr) do
    local d = arr[i]
    local activeMs = tonumber(d.activeMs) or 0
    local uptime = dur > 0 and math.min(1, activeMs / dur) or 0
    local apps = tonumber(d.applied) or 0
    local src = ""
    if d.sourceAbilityName and d.sourceAbilityName ~= "" then
      src = tostring(d.sourceAbilityName)
    elseif (tonumber(d.sourceAbilityId) or 0) > 0 then
      src = "id " .. tostring(d.sourceAbilityId)
    elseif (tonumber(d.id) or 0) > 0 then
      src = "id " .. tostring(d.id)
    end
    local rawKind = d.kind or "Effect"
    rows[i] = {
      name = d.name or "?",
      kind = rawKind,
      -- "Effect" is the combat-log leftover of your skill landing — not a lasting debuff
      kindTxt = (rawKind == "Effect") and "Skill hit" or rawKind,
      apps = apps,
      appsTxt = tostring(apps),
      uptime = uptime,
      uptimeTxt = fmtPct(uptime),
      activeTxt = fmtDur(activeMs),
      target = d.lastTarget or session.lastTargetName or "",
      sourceTxt = src,
      id = tonumber(d.id) or 0,
    }
  end
  return rows
end

local function buildProcModelRows(session, maxRows)
  maxRows = tonumber(maxRows) or LIST_MAX_ROWS
  local rows = {}
  if not session or type(session.sets) ~= "table" then return rows end
  local totalDamage = tonumber(session.totalDamage) or 0
  local dur = tonumber(session.durationMs) or 0
  local arr = {}
  for _, ps in pairs(session.sets) do
    if type(ps) == "table" then table.insert(arr, ps) end
  end
  table.sort(arr, function(a, b) return (tonumber(a.dmg) or 0) > (tonumber(b.dmg) or 0) end)
  for i = 1, math.min(maxRows, #arr) do
    local ps = arr[i]
    local dmg = tonumber(ps.dmg) or 0
    local hits = tonumber(ps.hits) or 0
    local share = totalDamage > 0 and (dmg / totalDamage) or 0
    local dps = dur > 0 and (dmg / (dur / 1000)) or 0
    local critPct = hits > 0 and ((tonumber(ps.crit) or 0) / hits) or 0
    local dotp = dmg > 0 and ((tonumber(ps.dot) or 0) / dmg) or 0
    local kind = (dotp > 0.95) and "DoT" or (dotp < 0.05) and "Direct" or "Mixed"
    rows[i] = {
      name = ps.name or "?",
      sub = string.format("%s share · %s DPS · %s hits · crit %s · %s · total %s",
        fmtPct(share), fmtDps(dps), tostring(hits), fmtPct(critPct), kind, fmtInt(dmg)),
      icon = nil,
      bar = nil,
      share = share,
      amountTxt = fmtInt(dmg),
      hitsTxt = tostring(hits),
      shareTxt = fmtPct(share),
      critTxt = fmtPct(critPct),
      kindTxt = kind,
      dpsTxt = fmtDps(dps),
    }
  end
  return rows
end

local function resolveDisplaySkillName(session, abilityId, rawName, slot, bar)
  abilityId = tonumber(abilityId) or 0
  local name = rawName
  if not isPlaceholderName(name) then return name end
  if abilityId > 0 then
    local n = getAbilityName(abilityId)
    if not isPlaceholderName(n) then return n end
    if session and type(session.skills) == "table" then
      local sk = session.skills[abilityId]
      if type(sk) == "table" and not isPlaceholderName(sk.name) then return sk.name end
    end
  end
  -- Slot snapshot
  slot = tonumber(slot) or 0
  if session and slot >= 3 and type(session.slottedAbilityBySlot) == "table" then
    local entry = session.slottedAbilityBySlot[tostring(bar or "Front") .. ":" .. tostring(slot)]
    if type(entry) == "table" then
      if not isPlaceholderName(entry.name) then return entry.name end
      local eid = tonumber(entry.id) or 0
      if eid > 0 then
        local n = getAbilityName(eid)
        if not isPlaceholderName(n) then return n end
      end
    end
  end
  if abilityId > 0 then return string.format("Ability %d", abilityId) end
  return "Unknown skill"
end

local function buildPerSkillWeaveModel(session, maxRows)
  maxRows = tonumber(maxRows) or 8
  local rows = {}
  if not session or type(session.weave) ~= "table" or type(session.weave.timeline) ~= "table" then
    return rows
  end
  local bySkill = {}
  for _, item in ipairs(session.weave.timeline) do
    if item and (item.kind == "skill" or item.kind == "postchannel") then
      local abilityId = tonumber(item.abilityId) or 0
      local rawName = item.skillName or item.label or ""
      local displayName = resolveDisplaySkillName(session, abilityId, rawName, item.slot, item.bar)
      local key = abilityId > 0 and ("id:" .. tostring(abilityId)) or string.lower(displayName)
      if not bySkill[key] then
        bySkill[key] = { name = displayName, abilityId = abilityId, good = 0, late = 0, missed = 0, fast = 0, total = 0 }
      elseif isPlaceholderName(bySkill[key].name) and not isPlaceholderName(displayName) then
        bySkill[key].name = displayName
      end
      local r = string.lower(tostring(item.result or ""))
      if r == "good" then bySkill[key].good = bySkill[key].good + 1
      elseif r == "late" then bySkill[key].late = bySkill[key].late + 1
      elseif r == "missed" then bySkill[key].missed = bySkill[key].missed + 1
      elseif r == "too fast" then bySkill[key].fast = bySkill[key].fast + 1 end
      bySkill[key].total = bySkill[key].total + 1
    end
  end
  local arr = {}
  for _, v in pairs(bySkill) do table.insert(arr, v) end
  table.sort(arr, function(a, b) return a.total > b.total end)
  for i = 1, math.min(maxRows, #arr) do
    local s = arr[i]
    local goodPct = s.total > 0 and (s.good / s.total) or 0
    local niceName = resolveDisplaySkillName(session, s.abilityId, s.name, nil, nil)
    rows[i] = {
      name = niceName,
      sub = string.format("good %s · G %d · L %d · M %d · F %d · n=%d",
        fmtPct(goodPct), s.good, s.late, s.missed, s.fast, s.total),
      icon = resolveSkillIcon(session, s.abilityId, niceName),
      bar = getSkillBar(session, s.abilityId),
      share = goodPct,
      goodTxt = fmtPct(goodPct),
      gTxt = tostring(s.good),
      lTxt = tostring(s.late),
      mTxt = tostring(s.missed),
      fTxt = tostring(s.fast),
      nTxt = tostring(s.total),
    }
  end
  return rows
end

-- Weapon-enchant / status DoTs the player does not refresh as skills
local function isWeaponEnchantStatusDot(name)
  local n = string.lower(tostring(name or ""))
  if n == "" then return false end
  if string.find(n, "hemorrhag", 1, true) or string.find(n, "bleeding", 1, true)
      or string.find(n, "poisoned", 1, true) or string.find(n, "burning", 1, true)
      or string.find(n, "diseased", 1, true) or string.find(n, "sundered", 1, true)
      or string.find(n, "concussed", 1, true) or string.find(n, "chilled", 1, true)
      or string.find(n, "overcharged", 1, true) then
    return true
  end
  return false
end

-- Prefer running activeMs (3.17.6+) over sparse-tick gap math; newest-only tails undercounted.
local function estimateDotUptimeEntry(entry, dur)
  dur = tonumber(dur) or 0
  if dur <= 0 or type(entry) ~= "table" then return 0, 0 end
  local tickN = tonumber(entry.tickCount) or (type(entry.ticks) == "table" and #entry.ticks) or 0
  local activeMs = tonumber(entry.activeMs)
  if activeMs and activeMs > 0 then
    local med = tonumber(entry.medianIntervalMs) or 0
    if med <= 0 and type(entry.ticks) == "table" and #entry.ticks >= 2 then
      local intervals = {}
      for i = 2, #entry.ticks do intervals[#intervals + 1] = entry.ticks[i] - entry.ticks[i - 1] end
      table.sort(intervals)
      med = intervals[math.ceil(#intervals / 2)] or 2000
    end
    if med <= 0 then med = 2000 end
    return math.min(1.0, (activeMs + med) / dur), tickN
  end
  local ticks = entry.ticks
  if type(ticks) ~= "table" or #ticks < 2 then return 0, tickN end
  local intervals = {}
  for i = 2, #ticks do intervals[#intervals + 1] = ticks[i] - ticks[i - 1] end
  table.sort(intervals)
  local medianInterval = intervals[math.ceil(#intervals / 2)] or 2000
  local maxGap = math.max(medianInterval * 2.5, 4000)
  local coveredMs = 0
  for i = 2, #ticks do
    local gap = ticks[i] - ticks[i - 1]
    if gap <= maxGap then coveredMs = coveredMs + gap end
  end
  coveredMs = coveredMs + medianInterval
  local n = #ticks
  if tickN < n then tickN = n end
  return math.min(1.0, coveredMs / dur), tickN
end

local function buildDotUptimeModel(session, maxRows)
  maxRows = tonumber(maxRows) or 6
  local rows = {}
  if not session or type(session.dotTicks) ~= "table" then return rows end
  local dur = tonumber(session.durationMs) or 0
  if dur <= 0 then return rows end
  local arr = {}
  for id, entry in pairs(session.dotTicks) do
    local ticks = entry and entry.ticks
    local hasActive = entry and tonumber(entry.activeMs) and tonumber(entry.activeMs) > 0
    if hasActive or (type(ticks) == "table" and #ticks >= 2) then
      local uptimePct, tickN = estimateDotUptimeEntry(entry, dur)
      local dname = entry.name or "?"
      table.insert(arr, {
        id = tonumber(id) or tonumber(entry.id) or 0,
        name = dname,
        uptime = uptimePct,
        ticks = tickN,
        isProc = isWeaponEnchantStatusDot(dname),
      })
    end
  end
  -- Maintainable DoTs first (worst uptime); enchant procs listed after with tag
  table.sort(arr, function(a, b)
    if (a.isProc and true or false) ~= (b.isProc and true or false) then
      return not a.isProc and b.isProc
    end
    return a.uptime < b.uptime
  end)
  for i = 1, math.min(maxRows, #arr) do
    local d = arr[i]
    local sub
    if d.isProc then
      sub = string.format("%s up · %d ticks · enchant/status (not skill-refresh)", fmtPct(d.uptime), d.ticks or 0)
    else
      local dq = session.dotQuality and session.dotQuality[d.id]
      if type(dq) == "table" and (tonumber(dq.gapCount) or 0) > 0 then
        sub = string.format(
          "%s up · %d ticks · %d long gap(s) · max gap %0.1fs",
          fmtPct(d.uptime), d.ticks or 0, dq.gapCount or 0, (tonumber(dq.maxGapMs) or 0) / 1000
        )
      else
        sub = string.format("%s uptime · %d ticks · no long gaps", fmtPct(d.uptime), d.ticks or 0)
      end
    end
    rows[i] = {
      name = d.name or "?",
      sub = sub,
      icon = resolveSkillIcon(session, d.id, d.name),
      bar = getSkillBar(session, d.id),
      share = d.uptime,
      isProc = d.isProc,
      gapCount = d.gapCount,
    }
  end
  return rows
end

local function denseSparkBuckets(session)
  local arr = {}
  if not session or type(session.buckets) ~= "table" then return arr end
  for idx, b in pairs(session.buckets) do
    if type(b) == "table" then
      table.insert(arr, { idx = tonumber(idx) or 0, dmg = tonumber(b.dmg) or 0 })
    end
  end
  table.sort(arr, function(a, b) return a.idx < b.idx end)
  return arr
end

local function collectLiveBarSlots(barLabel)
  local slots = {}
  if type(GetSlotBoundId) ~= "function" then return slots end
  local cat = nil
  if barLabel == "Front" and type(HOTBAR_CATEGORY_PRIMARY) ~= "nil" then
    cat = HOTBAR_CATEGORY_PRIMARY
  elseif barLabel == "Back" and type(HOTBAR_CATEGORY_BACKUP) ~= "nil" then
    cat = HOTBAR_CATEGORY_BACKUP
  end
  for slot = 3, 8 do
    local abilityId = 0
    local slotArg = slot
    if cat ~= nil then
      local ok, id = pcall(GetSlotBoundId, slot, cat)
      abilityId = ok and (tonumber(id) or 0) or 0
    else
      slotArg = (barLabel == "Back") and (slot + 17) or slot
      local ok, id = pcall(GetSlotBoundId, slotArg)
      abilityId = ok and (tonumber(id) or 0) or 0
    end
    -- Slot texture first (console-safe), then ability icon; never show "?" art.
    local icon = getSlotTextureFor(slotArg, cat) or resolveSlotIcon(abilityId)
    local name = ""
    if type(GetSlotName) == "function" then
      local okN, sn
      if cat ~= nil then okN, sn = pcall(GetSlotName, slot, cat)
      else okN, sn = pcall(GetSlotName, slotArg) end
      if okN and sn and not isPlaceholderName(sn) then
        name = (type(zo_strformat) == "function") and zo_strformat("<<1>>", sn) or sn
      end
    end
    if name == "" and abilityId > 0 then name = getAbilityName(abilityId) end
    if isPlaceholderName(name) then name = "" end
    slots[#slots + 1] = {
      slot = slot,
      id = abilityId,
      name = name,
      icon = icon,
      filled = abilityId > 0,
    }
  end
  return slots
end

local function collectBarSlots(session, barLabel)
  local slots = {}
  local hasSnapshot = session and type(session.slottedAbilityBySlot) == "table"
  local cat = nil
  if barLabel == "Front" and type(HOTBAR_CATEGORY_PRIMARY) ~= "nil" then
    cat = HOTBAR_CATEGORY_PRIMARY
  elseif barLabel == "Back" and type(HOTBAR_CATEGORY_BACKUP) ~= "nil" then
    cat = HOTBAR_CATEGORY_BACKUP
  end
  for slot = 3, 8 do
    local abilityId, name = 0, ""
    local snapIcon = nil
    if hasSnapshot then
      local entry = session.slottedAbilityBySlot[barLabel .. ":" .. slot]
      if type(entry) == "table" then
        abilityId = tonumber(entry.id) or 0
        name = entry.name or ""
        if entry.icon and not isBadIconTex(entry.icon) then snapIcon = entry.icon end
      end
    end
    if isPlaceholderName(name) then name = "" end
    if name == "" and abilityId > 0 then
      local resolved = getAbilityName(abilityId)
      if not isPlaceholderName(resolved) then name = resolved end
    end
    -- Prefer parse-time snapshot icon (scribed-safe), then live slot, then resolve.
    local icon = snapIcon
    if not icon and abilityId > 0 and type(GetSlotBoundId) == "function" then
      local ok, sid
      if cat ~= nil then ok, sid = pcall(GetSlotBoundId, slot, cat)
      else
        local mapped = (barLabel == "Back") and (slot + 17) or slot
        ok, sid = pcall(GetSlotBoundId, mapped)
      end
      if ok and tonumber(sid) == abilityId then
        icon = getSlotTextureFor((cat ~= nil) and slot or ((barLabel == "Back") and (slot + 17) or slot), cat)
      end
    end
    if not icon then icon = resolveSlotIcon(abilityId) end
    if not icon then icon = resolveSkillIcon(session, abilityId, name) end
    slots[#slots + 1] = {
      slot = slot,
      id = abilityId,
      name = name,
      icon = icon,
      filled = abilityId > 0,
    }
  end
  local any = false
  for _, s in ipairs(slots) do
    if (s.id or 0) > 0 then any = true break end
  end
  if not any then return collectLiveBarSlots(barLabel) end
  return slots
end

-- Must live above any refresh* that paints bar icons (console: no forward local refs)
local function refreshBarIcons(iconRows, slots)
  for i = 1, 6 do
    local ui = iconRows and iconRows[i]
    local slot = slots and slots[i]
    if not ui then
      -- skip
    elseif slot and (slot.filled or (slot.id or 0) > 0) then
      if ui.bg then
        ui.bg:SetCenterColor(0.14, 0.12, 0.09, 0.95)
        ui.bg:SetEdgeColor(THEME.cardEdgeR, THEME.cardEdgeG, THEME.cardEdgeB, 0.75)
      end
      if slot.icon then
        ui.icon:SetTexture(slot.icon)
        ui.icon:SetHidden(false)
        ui.icon:SetColor(1, 1, 1, 1)
      else
        ui.icon:SetHidden(true)
      end
    else
      if ui.bg then
        ui.bg:SetCenterColor(0.06, 0.08, 0.12, 0.80)
        ui.bg:SetEdgeColor(0.25, 0.32, 0.40, 0.40)
      end
      if ui.icon then ui.icon:SetHidden(true) end
    end
  end
end

-- Live slotted champion skills (constellation bar).
-- ESOUI uses HOTBAR_CATEGORY_CHAMPION + GetSlotBoundId(slot, hotbar) — not a
-- separate GetSlotBoundChampionSkillId(discipline, slot) API.
local function championSkillDescription(id)
  id = tonumber(id) or 0
  if id <= 0 then return "" end
  if type(GetChampionSkillDescription) == "function" then
    local ok, d = pcall(GetChampionSkillDescription, id)
    if ok and type(d) == "string" and d ~= "" then
      return (type(zo_strformat) == "function") and zo_strformat("<<1>>", d) or d
    end
  end
  -- Fallback: ability text for the champion skill’s linked ability
  if type(GetChampionAbilityId) == "function" and type(GetAbilityDescription) == "function" then
    local okA, abilityId = pcall(GetChampionAbilityId, id)
    abilityId = okA and (tonumber(abilityId) or 0) or 0
    if abilityId > 0 then
      local okD, d = pcall(GetAbilityDescription, abilityId)
      if okD and type(d) == "string" and d ~= "" then
        return (type(zo_strformat) == "function") and zo_strformat("<<1>>", d) or d
      end
    end
  end
  return ""
end

-- Map constellation → UI bucket.
-- ESOUI: GetChampionDisciplineType / GetChampionDisciplineName take **disciplineId**,
-- not the 1..N discipline index. Passing the index mis-labels trees (combat/fitness/craft cycle).
-- Returns: key ("combat"|"fitness"|"craft"|"unknown"), label, colorCode (RRGGBB)
local function mapDisciplineNameToConstellation(rawName)
  local dn = string.lower(tostring(rawName or ""))
  if dn == "" then return nil end
  -- Warfare / Combat (red) — damage constellation
  if string.find(dn, "warfare", 1, true) or string.find(dn, "combat", 1, true)
      or string.find(dn, "mage", 1, true) then
    return "combat", "Combat", "E85D5D"
  end
  -- Fitness / Conditioning (blue) — health constellation
  if string.find(dn, "fitness", 1, true) or string.find(dn, "condition", 1, true)
      or string.find(dn, "warrior", 1, true) then
    return "fitness", "Fitness", "5B9BD5"
  end
  -- Craft / World (green) — utility constellation
  if string.find(dn, "craft", 1, true) or string.find(dn, "world", 1, true)
      or string.find(dn, "thief", 1, true) then
    return "craft", "Craft", "6FBF73"
  end
  return nil
end

local function mapDisciplineTypeToConstellation(dtype)
  if dtype == nil then return nil end
  if type(CHAMPION_DISCIPLINE_TYPE_COMBAT) == "number" and dtype == CHAMPION_DISCIPLINE_TYPE_COMBAT then
    return "combat", "Combat", "E85D5D"
  end
  if type(CHAMPION_DISCIPLINE_TYPE_CONDITIONING) == "number" and dtype == CHAMPION_DISCIPLINE_TYPE_CONDITIONING then
    return "fitness", "Fitness", "5B9BD5"
  end
  if type(CHAMPION_DISCIPLINE_TYPE_WORLD) == "number" and dtype == CHAMPION_DISCIPLINE_TYPE_WORLD then
    return "craft", "Craft", "6FBF73"
  end
  -- Do NOT guess bare 0/1/2 — order differs by client and caused the rotated labels.
  return nil
end

-- Well-known star names (last resort when discipline APIs are wrong/missing)
local function mapSkillNameToConstellation(skillName)
  local n = string.lower(tostring(skillName or ""))
  if n == "" then return nil end
  -- Warfare
  if string.find(n, "thaumaturge", 1, true) or string.find(n, "master%-at%-arms", 1, false)
      or string.find(n, "master at arms", 1, true) or string.find(n, "backstabber", 1, true)
      or string.find(n, "fighting finesse", 1, true) or string.find(n, "deadly aim", 1, true)
      or string.find(n, "wrathful", 1, true) or string.find(n, "biting aura", 1, true)
      or string.find(n, "exploite", 1, true) or string.find(n, "force of nature", 1, true)
      or string.find(n, "weapon expert", 1, true) or string.find(n, "arcane supremacy", 1, true)
      or string.find(n, "dulled weapons", 1, true) or string.find(n, "piercing", 1, true)
      or string.find(n, "reaving blows", 1, true) or string.find(n, "occult overlord", 1, true)
      or string.find(n, "deadly intent", 1, true) then
    return "combat", "Combat", "E85D5D"
  end
  -- Fitness
  if string.find(n, "boundless vitality", 1, true) or string.find(n, "fortified", 1, true)
      or string.find(n, "rejuvenation", 1, true) or string.find(n, "ironclad", 1, true)
      or string.find(n, "tireless", 1, true) or string.find(n, "bastion", 1, true)
      or string.find(n, "spirit master", 1, true) or string.find(n, "strategic reserve", 1, true)
      or string.find(n, "hardy", 1, true) or string.find(n, "elemental aegis", 1, true)
      or string.find(n, "survival instincts", 1, true) or string.find(n, "pain's refuge", 1, true)
      or string.find(n, "sustained by suffering", 1, true) or string.find(n, "slippery", 1, true)
      or string.find(n, "defiance", 1, true) or string.find(n, "expert evasion", 1, true)
      or string.find(n, "jubilee", 1, true) or string.find(n, "shield master", 1, true)
      or string.find(n, "sprinter", 1, true) or string.find(n, "temerity", 1, true)
      or string.find(n, "nourishing", 1, true) or string.find(n, "mending", 1, true)
      or string.find(n, "hero's vigor", 1, true) then
    return "fitness", "Fitness", "5B9BD5"
  end
  -- Craft
  if string.find(n, "peace of mind", 1, true) or string.find(n, "rationer", 1, true)
      or string.find(n, "steed's blessing", 1, true) or string.find(n, "steeds blessing", 1, true)
      or string.find(n, "liquid efficiency", 1, true) or string.find(n, "treasure hunter", 1, true)
      or string.find(n, "gilded fingers", 1, true) or string.find(n, "soul reservoir", 1, true)
      or string.find(n, "breakfall", 1, true) or string.find(n, "out of sight", 1, true)
      or string.find(n, "fleet phantom", 1, true) or string.find(n, "wanderer", 1, true)
      or string.find(n, "friend of trolls", 1, true) or string.find(n, "homemaker", 1, true)
      or string.find(n, "master gatherer", 1, true) or string.find(n, "plentiful harvest", 1, true)
      or string.find(n, "renowned", 1, true) or string.find(n, "shadowstrike", 1, true)
      or string.find(n, "siphoning spells", 1, true) or string.find(n, "war mount", 1, true)
      or string.find(n, "inspiration boost", 1, true) then
    return "craft", "Craft", "6FBF73"
  end
  return nil
end

-- disciplineId: preferred (from GetRequiredChampionDisciplineIdForSlot or GetChampionDisciplineId)
-- skillId/skillName: used for fallbacks
local function championConstellation(skillId, disciplineId, skillName)
  skillId = tonumber(skillId) or 0
  disciplineId = tonumber(disciplineId) or 0

  -- 1) From known discipline id (slot or resolved)
  if disciplineId > 0 then
    if type(GetChampionDisciplineName) == "function" then
      local okDn, dn = pcall(GetChampionDisciplineName, disciplineId)
      local mapped = mapDisciplineNameToConstellation(okDn and dn or "")
      if mapped then return mapped end
    end
    if type(GetChampionDisciplineType) == "function" then
      local okT, dtype = pcall(GetChampionDisciplineType, disciplineId)
      if okT then
        local mapped = mapDisciplineTypeToConstellation(dtype)
        if mapped then return mapped end
      end
    end
  end

  -- 2) Resolve discipline id by finding skill under each discipline INDEX
  if skillId > 0 and type(GetNumChampionDisciplines) == "function"
      and type(GetNumChampionDisciplineSkills) == "function"
      and type(GetChampionSkillId) == "function" then
    local okN, numDisc = pcall(GetNumChampionDisciplines)
    numDisc = okN and (tonumber(numDisc) or 0) or 0
    for di = 1, numDisc do
      local okS, nSkills = pcall(GetNumChampionDisciplineSkills, di)
      nSkills = okS and (tonumber(nSkills) or 0) or 0
      for si = 1, nSkills do
        local okId, sid = pcall(GetChampionSkillId, di, si)
        sid = okId and (tonumber(sid) or 0) or 0
        if sid == skillId then
          local resolvedDiscId = di
          if type(GetChampionDisciplineId) == "function" then
            local okD, d = pcall(GetChampionDisciplineId, di)
            if okD and d then resolvedDiscId = d end
          end
          -- Name first (most reliable across renames)
          if type(GetChampionDisciplineName) == "function" then
            local okDn, dn = pcall(GetChampionDisciplineName, resolvedDiscId)
            local mapped = mapDisciplineNameToConstellation(okDn and dn or "")
            if mapped then return mapped end
          end
          if type(GetChampionDisciplineType) == "function" then
            local okT, dtype = pcall(GetChampionDisciplineType, resolvedDiscId)
            if okT then
              local mapped = mapDisciplineTypeToConstellation(dtype)
              if mapped then return mapped end
            end
          end
          break
        end
      end
    end
  end

  -- 3) Skill-name heuristics
  local mapped = mapSkillNameToConstellation(skillName)
  if mapped then return mapped end
  if skillId > 0 and type(GetChampionSkillName) == "function" then
    local ok, n = pcall(GetChampionSkillName, skillId)
    mapped = mapSkillNameToConstellation(ok and n or "")
    if mapped then return mapped end
  end

  return "unknown", "Other", "AAAAAA"
end

local function collectSlottedChampionSkills(maxN)
  maxN = tonumber(maxN) or 12
  local out = {}
  local seen = {}

  local function addSkill(id, name, disciplineId)
    id = tonumber(id) or 0
    if id <= 0 or seen[id] then return end
    seen[id] = true
    if (not name or name == "") and type(GetChampionSkillName) == "function" then
      local ok, n = pcall(GetChampionSkillName, id)
      if ok and n and n ~= "" then
        name = (type(zo_strformat) == "function") and zo_strformat("<<1>>", n) or n
      end
    end
    -- Prefer champion name; some clients only expose ability name
    if (not name or name == "") and type(GetChampionAbilityId) == "function" and type(GetAbilityName) == "function" then
      local okA, abilityId = pcall(GetChampionAbilityId, id)
      abilityId = okA and (tonumber(abilityId) or 0) or 0
      if abilityId > 0 then
        local okN, n = pcall(GetAbilityName, abilityId)
        if okN and n and n ~= "" then
          name = (type(zo_strformat) == "function") and zo_strformat("<<1>>", n) or n
        end
      end
    end
    if not name or name == "" then name = string.format("CP %d", id) end
    local cKey = championConstellation(id, disciplineId, name)
    out[#out + 1] = {
      id = id,
      name = name,
      desc = championSkillDescription(id),
      constellation = cKey,
      disciplineId = tonumber(disciplineId) or 0,
    }
  end

  local function looksLikeChampionSkillId(id)
    id = tonumber(id) or 0
    if id <= 0 then return false end
    if type(GetChampionSkillName) == "function" then
      local ok, n = pcall(GetChampionSkillName, id)
      if ok and type(n) == "string" and n ~= "" then return true end
    end
    if type(GetChampionSkillType) == "function" then
      local ok, t = pcall(GetChampionSkillType, id)
      if ok and t ~= nil then return true end
    end
    return false
  end

  ------------------------------------------------------------------
  -- Path A (primary, matches ESOUI champion assignable action bar):
  --   for slot in GetAssignableChampionBarStartAndEndSlots()
  --     if GetSlotType(slot, HOTBAR_CATEGORY_CHAMPION) == ACTION_TYPE_CHAMPION_SKILL
  --       id = GetSlotBoundId(slot, HOTBAR_CATEGORY_CHAMPION)
  ------------------------------------------------------------------
  local hotbar = nil
  if type(HOTBAR_CATEGORY_CHAMPION) == "number" then
    hotbar = HOTBAR_CATEGORY_CHAMPION
  end

  local startSlot, endSlot = nil, nil
  if type(GetAssignableChampionBarStartAndEndSlots) == "function" then
    local ok, a, b = pcall(GetAssignableChampionBarStartAndEndSlots)
    if ok then
      startSlot = tonumber(a)
      endSlot = tonumber(b)
    end
  end
  -- Typical champion bar is 12 slots (4 per constellation × 3); pad range if API missing
  if not startSlot or not endSlot or endSlot < startSlot then
    startSlot, endSlot = 1, 12
  end

  if type(GetSlotBoundId) == "function" then
    local championActionType = (type(ACTION_TYPE_CHAMPION_SKILL) == "number") and ACTION_TYPE_CHAMPION_SKILL or nil
    for slot = startSlot, endSlot do
      local skillId = nil
      local discId = nil
      if hotbar ~= nil then
        -- Prefer typed champion slots, but NEVER skip a bound id solely because
        -- GetSlotType mismatches (console sometimes leaves type unset → missing 4th Warfare star).
        local typedId = nil
        if type(GetSlotType) == "function" and championActionType ~= nil then
          local okT, slotType = pcall(GetSlotType, slot, hotbar)
          if okT and slotType == championActionType then
            local ok, id = pcall(GetSlotBoundId, slot, hotbar)
            if ok then typedId = tonumber(id) end
          end
        end
        if typedId and typedId > 0 then
          skillId = typedId
        else
          local ok, id = pcall(GetSlotBoundId, slot, hotbar)
          id = ok and (tonumber(id) or 0) or 0
          if id > 0 and looksLikeChampionSkillId(id) then skillId = id end
        end
        -- Slot is bound to a constellation — most reliable discipline source
        if type(GetRequiredChampionDisciplineIdForSlot) == "function" then
          local okD, d = pcall(GetRequiredChampionDisciplineIdForSlot, slot, hotbar)
          if okD then discId = tonumber(d) end
        end
      else
        -- No HOTBAR_CATEGORY_CHAMPION constant — try slot-only / common hotbar ids
        for _, hb in ipairs({ nil, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 }) do
          local ok, id
          if hb == nil then
            ok, id = pcall(GetSlotBoundId, slot)
          else
            ok, id = pcall(GetSlotBoundId, slot, hb)
          end
          id = ok and (tonumber(id) or 0) or 0
          if id > 0 and looksLikeChampionSkillId(id) then
            skillId = id
            if type(GetRequiredChampionDisciplineIdForSlot) == "function" and hb ~= nil then
              local okD, d = pcall(GetRequiredChampionDisciplineIdForSlot, slot, hb)
              if okD then discId = tonumber(d) end
            end
            break
          end
        end
      end
      if skillId and skillId > 0 then
        if looksLikeChampionSkillId(skillId) or championActionType ~= nil then
          addSkill(skillId, nil, discId)
        end
      end
      if #out >= maxN then break end
    end
  end

  ------------------------------------------------------------------
  -- Path B: legacy / alternate name (some docs list this; usually nil)
  ------------------------------------------------------------------
  if type(GetSlotBoundChampionSkillId) == "function" then
    local discTypes = {}
    if type(CHAMPION_DISCIPLINE_TYPE_ITERATION_BEGIN) == "number"
        and type(CHAMPION_DISCIPLINE_TYPE_ITERATION_END) == "number" then
      for d = CHAMPION_DISCIPLINE_TYPE_ITERATION_BEGIN, CHAMPION_DISCIPLINE_TYPE_ITERATION_END do
        discTypes[#discTypes + 1] = d
      end
    else
      for _, key in ipairs({
        "CHAMPION_DISCIPLINE_TYPE_COMBAT",
        "CHAMPION_DISCIPLINE_TYPE_CONDITIONING",
        "CHAMPION_DISCIPLINE_TYPE_WORLD",
      }) do
        if type(_G[key]) == "number" then discTypes[#discTypes + 1] = _G[key] end
      end
    end
    if #discTypes == 0 then discTypes = { 0, 1, 2 } end
    for _, disc in ipairs(discTypes) do
      for slot = 1, 4 do
        local ok, sid = pcall(GetSlotBoundChampionSkillId, disc, slot)
        if ok and sid then addSkill(sid, nil) end
        if #out >= maxN then return out end
      end
    end
  end

  ------------------------------------------------------------------
  -- Path C: fill holes only. If Path A already read a full bar, extra
  -- IsChampionSkillSlotted hits minted a new Build ID on the next dummy.
  ------------------------------------------------------------------
  if #out < 8 and type(GetNumChampionDisciplines) == "function"
      and type(GetChampionSkillId) == "function"
      and type(IsChampionSkillSlotted) == "function" then
    local okN, numDisc = pcall(GetNumChampionDisciplines)
    numDisc = okN and (tonumber(numDisc) or 0) or 0
    for di = 1, numDisc do
      local numSkills = 0
      if type(GetNumChampionDisciplineSkills) == "function" then
        local okS, n = pcall(GetNumChampionDisciplineSkills, di)
        numSkills = okS and (tonumber(n) or 0) or 0
      end
      local discId = di
      if type(GetChampionDisciplineId) == "function" then
        local okD, d = pcall(GetChampionDisciplineId, di)
        if okD and d then discId = d end
      end
      for si = 1, numSkills do
        local okId, skillId = pcall(GetChampionSkillId, di, si)
        skillId = okId and (tonumber(skillId) or 0) or 0
        if skillId > 0 then
          local okSl, sl = pcall(IsChampionSkillSlotted, skillId)
          if okSl and sl then addSkill(skillId, nil, discId) end
        end
        if #out >= maxN then break end
      end
      if #out >= maxN then break end
    end
  end

  ------------------------------------------------------------------
  -- Path D: CHAMPION_DATA_MANAGER if still empty
  ------------------------------------------------------------------
  if #out == 0 and type(CHAMPION_DATA_MANAGER) == "table" then
    local mgr = CHAMPION_DATA_MANAGER
    -- Prefer iterating hotbar slots again via manager skill lookup after path A
    -- Some clients expose GetChampionSkillData / discipline iterators
    if type(mgr.ChampionDisciplineDataIterator) == "function" then
      local okIter, iterFn, iterState, iterVar = pcall(function()
        return mgr:ChampionDisciplineDataIterator()
      end)
      if okIter and type(iterFn) == "function" then
        for _, disciplineData in iterFn, iterState, iterVar do
          if type(disciplineData) == "table" and type(disciplineData.ChampionSkillDataIterator) == "function" then
            local okS, sFn, sState, sVar = pcall(function()
              return disciplineData:ChampionSkillDataIterator()
            end)
            if okS and type(sFn) == "function" then
              for _, skillData in sFn, sState, sVar do
                if type(skillData) == "table" then
                  local id = nil
                  if type(skillData.GetId) == "function" then
                    local okI, v = pcall(function() return skillData:GetId() end)
                    if okI then id = v end
                  end
                  id = tonumber(id) or 0
                  -- Only include if a slot-bound check exists on the skill data
                  local isSlotted = false
                  if type(IsChampionSkillSlotted) == "function" and id > 0 then
                    local okSl, sl = pcall(IsChampionSkillSlotted, id)
                    isSlotted = okSl and sl and true or false
                  end
                  if isSlotted and id > 0 then addSkill(id, nil) end
                end
                if #out >= maxN then return out end
              end
            end
          end
        end
      end
    end
  end

  return out
end

---------------------------------------------------------------------
-- Live character helpers: Mundus + base/buffed stats
---------------------------------------------------------------------
local function captureActiveFood()
  -- Food/drink is a long player buff. Match common names + long remaining duration.
  if type(GetNumBuffs) ~= "function" or type(GetUnitBuffInfo) ~= "function" then return nil end
  local okN, n = pcall(GetNumBuffs, "player")
  n = okN and (tonumber(n) or 0) or 0
  local bestName, bestRemain = nil, 0
  for i = 1, n do
    local buffName, timeStarted, timeEnding, buffSlot, stackCount, iconFilename,
      buffType, effectType, abilityType, statusEffectType, abilityId, canClickOff,
      castByPlayer
    local ok = false
    -- Prefer full unpack when available
    ok, buffName, timeStarted, timeEnding, buffSlot, stackCount, iconFilename,
      buffType, effectType, abilityType, statusEffectType, abilityId, canClickOff,
      castByPlayer = pcall(GetUnitBuffInfo, "player", i)
    if not ok or type(buffName) ~= "string" then
      ok, buffName = pcall(function()
        return select(1, GetUnitBuffInfo("player", i))
      end)
    end
    if ok and type(buffName) == "string" and buffName ~= "" then
      local plain = stripColorLocal(buffName)
      plain = (type(zo_strformat) == "function") and zo_strformat("<<1>>", plain) or plain
      local low = string.lower(plain)
      local remain = 0
      if tonumber(timeEnding) and type(GetGameTimeSeconds) == "function" then
        remain = math.max(0, tonumber(timeEnding) - GetGameTimeSeconds())
      elseif tonumber(timeEnding) and tonumber(timeStarted) then
        remain = math.max(0, tonumber(timeEnding) - tonumber(timeStarted))
      end
      local nameHit = string.find(low, "food", 1, true) or string.find(low, "drink", 1, true)
          or string.find(low, "meal", 1, true) or string.find(low, "gourmet", 1, true)
          or string.find(low, "witchmother", 1, true) or string.find(low, "dubious", 1, true)
          or string.find(low, "orzorga", 1, true) or string.find(low, "psijic", 1, true)
          or string.find(low, "candied", 1, true) or string.find(low, "bewitched", 1, true)
          or string.find(low, "clockwork", 1, true) or string.find(low, "cava", 1, true)
          or string.find(low, "ghastly", 1, true) or string.find(low, "jubilee", 1, true)
          or string.find(low, "frosted", 1, true) or string.find(low, "corrupted", 1, true)
          or string.find(low, "artaeum", 1, true) or string.find(low, "//", 1, true) -- rare
      -- Long remaining duration + not a skill buff: likely food (30m–2h)
      local longConsumable = remain >= 60 * 20 and remain <= 60 * 150
          and not string.find(low, "major ", 1, true) and not string.find(low, "minor ", 1, true)
          and not string.find(low, "weapon", 1, true) and not string.find(low, "armor", 1, true)
      if nameHit or longConsumable then
        if remain >= bestRemain then
          bestRemain = remain
          bestName = plain
        end
      end
    end
  end
  return bestName
end
M.CaptureActiveFood = captureActiveFood

local function captureActiveMundus()
  -- Prefer active buff scan (mundus is an activated stone, not worn gear)
  if type(GetNumBuffs) == "function" and type(GetUnitBuffInfo) == "function" then
    local okN, n = pcall(GetNumBuffs, "player")
    n = okN and (tonumber(n) or 0) or 0
    for i = 1, n do
      local ok, buffName = pcall(GetUnitBuffInfo, "player", i)
      if ok and type(buffName) == "string" and buffName ~= "" then
        local mundus = canonicalMundusName(buffName)
        if mundus then return mundus end
      end
    end
  end
  return nil
end
M.CaptureActiveMundus = captureActiveMundus
M.CanonicalMundusName = canonicalMundusName

local function readPlayerStat(statConst, bonusOpt, softOpt)
  if type(GetPlayerStat) ~= "function" or type(statConst) ~= "number" then return nil end
  local ok, v
  if bonusOpt ~= nil and softOpt ~= nil then
    ok, v = pcall(GetPlayerStat, statConst, bonusOpt, softOpt)
  elseif bonusOpt ~= nil then
    ok, v = pcall(GetPlayerStat, statConst, bonusOpt)
  else
    ok, v = pcall(GetPlayerStat, statConst)
  end
  if ok then return tonumber(v) end
  return nil
end

-- Crit rating → chance fraction (CP160 ≈ 219 rating per 1%)
local function ratingToCritFraction(rating)
  rating = tonumber(rating) or 0
  if rating <= 0 then return 0 end
  if rating <= 1 then return rating end
  if rating <= 100 then return rating / 100 end
  return math.min(1, rating / 21900)
end

local function critFractionFromRatings(weaponRating, spellRating)
  -- Prefer rating conversion — GetCriticalStrikeChance is unreliable on console
  -- and can inflate to ~60%+ vs character sheet ~47%.
  local fromRating = math.max(ratingToCritFraction(weaponRating), ratingToCritFraction(spellRating))
  if fromRating >= 0.05 then return fromRating end
  if type(GetCriticalStrikeChance) == "function" then
    local ok, v = pcall(GetCriticalStrikeChance)
    if ok and tonumber(v) then
      local f = tonumber(v)
      if f > 1.5 then f = f / 100 end
      if f >= 0.05 and f <= 1 then return f end
    end
  end
  return fromRating
end

-- Drop "base" values that strip gear (e.g. weapon dmg 1000) or equal buffed when
-- the API does not actually separate temporary bonuses.
local function saneBaseStat(base, buffed, kind)
  base, buffed = tonumber(base), tonumber(buffed)
  if base == nil then return nil end
  if buffed == nil or buffed <= 0 then return base end
  if kind == "power" then
    -- CP160 geared WD/SD is almost never below ~2k; 1000-ish means API stripped gear
    if base > 0 and base < 1500 and buffed >= 3000 then return nil end
    if base < buffed * 0.25 and buffed >= 2000 then return nil end
  elseif kind == "resource" then
    if base <= 0 then return nil end
    -- if identical to buffed, leave it (delta shows —); still valid as unbuffed when no temp
  elseif kind == "pen" then
    if base < 0 then return nil end
  end
  return base
end

local function capturePlayerStats()
  -- TOTAL (buffed) = full current stats (food + gear + temporary major/minor when up)
  -- UNBUFFED (base) = without temporary bonuses when API allows — NOT "naked gear strip"
  -- Note: end-of-fight TOTAL includes combat buffs; character sheet at rest will read lower.
  local applyBonus = (type(STAT_BONUS_OPTION_APPLY_ALL) == "number") and STAT_BONUS_OPTION_APPLY_ALL
    or (type(STAT_BONUS_OPTION_APPLY_BONUS) == "number") and STAT_BONUS_OPTION_APPLY_BONUS
    or nil
  local noBonus = (type(STAT_BONUS_OPTION_DONT_APPLY_BONUSES) == "number") and STAT_BONUS_OPTION_DONT_APPLY_BONUSES
    or (type(STAT_BONUS_OPTION_DONT_APPLY_BONUS) == "number") and STAT_BONUS_OPTION_DONT_APPLY_BONUS
    or (type(STAT_BONUS_OPTION_IGNORE_ALL) == "number") and STAT_BONUS_OPTION_IGNORE_ALL
    or nil
  local softOn = (type(STAT_SOFT_CAP_OPTION_APPLY_SOFT_CAP) == "number") and STAT_SOFT_CAP_OPTION_APPLY_SOFT_CAP or nil
  local softOff = (type(STAT_SOFT_CAP_OPTION_DONT_APPLY_SOFT_CAP) == "number") and STAT_SOFT_CAP_OPTION_DONT_APPLY_SOFT_CAP or nil

  local function pair(statKey, kind)
    local const = _G[statKey]
    if type(const) ~= "number" then return nil, nil end
    -- Prefer simple GetPlayerStat first (matches character sheet closely on console)
    local buffed = readPlayerStat(const, nil)
      or readPlayerStat(const, applyBonus, softOn)
      or readPlayerStat(const, applyBonus)
    local base = nil
    if noBonus ~= nil then
      base = readPlayerStat(const, noBonus, softOff)
        or readPlayerStat(const, noBonus)
    end
    base = saneBaseStat(base, buffed, kind or "other")
    -- Only fall back to buffed when base truly missing — never invent fake 0 unbuffed
    return base, buffed
  end

  local bCritW, cCritW = pair("STAT_CRITICAL_STRIKE", "other")
  local bCritS, cCritS = pair("STAT_SPELL_CRITICAL", "other")
  local bPenP, cPenP = pair("STAT_PHYSICAL_PENETRATION", "pen")
  local bPenS, cPenS = pair("STAT_SPELL_PENETRATION", "pen")
  local bWd, cWd = pair("STAT_POWER", "power")
  if cWd == nil then bWd, cWd = pair("STAT_WEAPON_POWER", "power") end
  local bSd, cSd = pair("STAT_SPELL_POWER", "power")
  local bHp, cHp = pair("STAT_HEALTH_MAX", "resource")
  local bMag, cMag = pair("STAT_MAGICKA_MAX", "resource")
  local bStam, cStam = pair("STAT_STAMINA_MAX", "resource")
  local bPhysRes, cPhysRes = pair("STAT_PHYSICAL_RESIST", "other")
  if cPhysRes == nil then bPhysRes, cPhysRes = pair("STAT_PHYSICAL_RESISTANCE", "other") end
  local bSpellRes, cSpellRes = pair("STAT_SPELL_RESIST", "other")
  if cSpellRes == nil then bSpellRes, cSpellRes = pair("STAT_SPELL_RESISTANCE", "other") end
  local bCritDmg, cCritDmg = pair("STAT_CRITICAL_DAMAGE", "other")
  if cCritDmg == nil then bCritDmg, cCritDmg = pair("STAT_CRITICAL_STRIKE_DAMAGE", "other") end
  local bMagRec, cMagRec = pair("STAT_MAGICKA_REGEN_COMBAT", "other")
  if cMagRec == nil then bMagRec, cMagRec = pair("STAT_MAGICKA_REGEN", "other") end
  local bHpRec, cHpRec = pair("STAT_HEALTH_REGEN_COMBAT", "other")
  if cHpRec == nil then bHpRec, cHpRec = pair("STAT_HEALTH_REGEN", "other") end
  local bStamRec, cStamRec = pair("STAT_STAMINA_REGEN_COMBAT", "other")
  if cStamRec == nil then bStamRec, cStamRec = pair("STAT_STAMINA_REGEN", "other") end
  local bCritRes, cCritRes = pair("STAT_CRITICAL_RESISTANCE", "other")

  -- Attribute point distribution (spent on Magicka / Health / Stamina)
  local attrMag, attrHp, attrStam = nil, nil, nil
  if type(GetAttributeSpentPoints) == "function" then
    local function attrPts(attrConst)
      if type(attrConst) ~= "number" then return nil end
      local ok, v = pcall(GetAttributeSpentPoints, attrConst)
      if ok then return tonumber(v) end
      return nil
    end
    attrMag = attrPts(_G.ATTRIBUTE_MAGICKA)
    attrHp = attrPts(_G.ATTRIBUTE_HEALTH)
    attrStam = attrPts(_G.ATTRIBUTE_STAMINA)
  end
  if (attrMag == nil or attrHp == nil or attrStam == nil) and type(GetUnitAttribute) == "function" then
    local function unitAttr(attrConst)
      if type(attrConst) ~= "number" then return nil end
      local ok, v = pcall(GetUnitAttribute, "player", attrConst)
      if ok then return tonumber(v) end
      return nil
    end
    attrMag = attrMag or unitAttr(_G.ATTRIBUTE_MAGICKA)
    attrHp = attrHp or unitAttr(_G.ATTRIBUTE_HEALTH)
    attrStam = attrStam or unitAttr(_G.ATTRIBUTE_STAMINA)
  end

  -- Resources: use GetUnitPowerMax ONLY as fill-in when GetPlayerStat returned nothing.
  -- Never override a higher/lower sheet value — that inflated Mag/HP/Stam vs character sheet.
  if type(GetUnitPowerMax) == "function" then
    local function fillPower(cur, powerType)
      if (tonumber(cur) or 0) > 0 then return cur end
      if type(powerType) ~= "number" then return cur end
      local ok, v = pcall(GetUnitPowerMax, "player", powerType)
      if ok and tonumber(v) and tonumber(v) > 0 then return tonumber(v) end
      return cur
    end
    cHp = fillPower(cHp, _G.POWERTYPE_HEALTH)
    cMag = fillPower(cMag, _G.POWERTYPE_MAGICKA)
    cStam = fillPower(cStam, _G.POWERTYPE_STAMINA)
  end

  local liveCrit = critFractionFromRatings(cCritW, cCritS)
  local baseCrit = critFractionFromRatings(bCritW, bCritS)
  -- If base crit unavailable, leave nil (UI shows —) rather than cloning inflated buffed
  if bCritW == nil and bCritS == nil then baseCrit = nil end

  local canDelta = false
  local function anyDelta(b, c)
    if b == nil or c == nil then return false end
    return math.abs((tonumber(c) or 0) - (tonumber(b) or 0)) >= 1
  end
  if anyDelta(bHp, cHp) or anyDelta(bMag, cMag) or anyDelta(bStam, cStam)
      or anyDelta(bWd, cWd) or anyDelta(bSd, cSd)
      or anyDelta(bPenP, cPenP) or anyDelta(bPenS, cPenS) then
    canDelta = true
  end
  if baseCrit and liveCrit and math.abs(liveCrit - baseCrit) >= 0.002 then canDelta = true end

  local foodName = nil
  if type(captureActiveFood) == "function" then
    local okF, f = pcall(captureActiveFood)
    if okF and type(f) == "string" and f ~= "" then foodName = f end
    if okF and type(f) == "table" and f.name then foodName = f.name end
  end

  local snap = {
    atMs = (type(GetGameTimeMilliseconds) == "function") and GetGameTimeMilliseconds() or 0,
    wallClock = (type(os) == "table" and type(os.time) == "function") and os.time() or 0,
    mundus = captureActiveMundus(),
    food = foodName,
    canDelta = canDelta,
    attributes = {
      magicka = attrMag,
      health = attrHp,
      stamina = attrStam,
    },
    base = {
      critWeapon = bCritW, critSpell = bCritS,
      penPhysical = bPenP, penSpell = bPenS,
      weaponDamage = bWd, spellDamage = bSd,
      health = bHp, magicka = bMag, stamina = bStam,
      physResist = bPhysRes, spellResist = bSpellRes,
      critDamage = bCritDmg,
      critChance = baseCrit,
      magickaRecovery = bMagRec, healthRecovery = bHpRec, staminaRecovery = bStamRec,
      critResist = bCritRes,
    },
    buffed = {
      critWeapon = cCritW, critSpell = cCritS,
      penPhysical = cPenP, penSpell = cPenS,
      weaponDamage = cWd, spellDamage = cSd,
      health = cHp, magicka = cMag, stamina = cStam,
      physResist = cPhysRes, spellResist = cSpellRes,
      critDamage = cCritDmg,
      critChance = liveCrit,
      magickaRecovery = cMagRec, healthRecovery = cHpRec, staminaRecovery = cStamRec,
      critResist = cCritRes,
    },
  }
  local function maxOf(a, b) return math.max(tonumber(a) or 0, tonumber(b) or 0) end
  snap.base.pen = maxOf(snap.base.penPhysical, snap.base.penSpell)
  snap.buffed.pen = maxOf(snap.buffed.penPhysical, snap.buffed.penSpell)
  snap.base.power = maxOf(snap.base.weaponDamage, snap.base.spellDamage)
  snap.buffed.power = maxOf(snap.buffed.weaponDamage, snap.buffed.spellDamage)
  return snap
end
M.CapturePlayerStats = capturePlayerStats

---------------------------------------------------------------------
-- Build fingerprint + parse-time build snapshot (Phase 1 foundations)
---------------------------------------------------------------------
local function simpleHashHex(str)
  str = tostring(str or "")
  local h = 2166136261
  for i = 1, #str do
    h = (h * 16777619) % 4294967296
    h = (h + string.byte(str, i)) % 4294967296
  end
  return string.format("%08x", h)
end

local function sortedIdList(ids)
  local t = {}
  for _, id in ipairs(ids or {}) do
    id = tonumber(id) or 0
    if id > 0 then t[#t + 1] = id end
  end
  table.sort(t)
  return t
end

local function barSlotIds(session, barLabel)
  local ids = { 0, 0, 0, 0, 0, 0 }
  if session and type(session.slottedAbilityBySlot) == "table" then
    for slot = 3, 8 do
      local entry = session.slottedAbilityBySlot[barLabel .. ":" .. slot]
      if type(entry) == "table" then
        ids[slot - 2] = tonumber(entry.id) or 0
      end
    end
  end
  return ids
end

-- Prefer non-zero slot ids from start snapshot when end re-read is incomplete.
-- Arrays are always slot 3..8 in order (index 1 = slot 3). Never compact-skip empties.
local function mergeBarSlotIds(primary, fallback)
  local out = {}
  for i = 1, 6 do
    local a = tonumber(primary and primary[i]) or 0
    local b = tonumber(fallback and fallback[i]) or 0
    out[i] = (a > 0 and a) or b
  end
  return out
end

local function barSlotIdsFromBuild(build, side)
  local ids = { 0, 0, 0, 0, 0, 0 }
  local slots = build and build.bars and build.bars[side]
  if type(slots) == "table" then
    for _, s in ipairs(slots) do
      local slot = tonumber(s.slot) or 0
      local idx = slot - 2 -- 3..8 → 1..6
      if idx >= 1 and idx <= 6 then
        local id = tonumber(s.id) or 0
        if id > 0 then ids[idx] = id end
      end
    end
  end
  return ids
end

local function countNonZeroIds(ids)
  local n = 0
  for i = 1, #(ids or {}) do
    if (tonumber(ids[i]) or 0) > 0 then n = n + 1 end
  end
  return n
end

-- Perfected vs non-Perfected was minting a new hash with the same gear.
local function canonicalizeSetName(n)
  local s = string.lower(tostring(n or ""))
  s = s:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  s = s:gsub("^perfected%s+", "")
  s = s:gsub("^perfect%s+", "")
  return s
end

local function lastStableBuild()
  local sv = R and R.SV
  if type(sv) == "table" and type(sv.lastStableBuild) == "table" then
    return sv.lastStableBuild
  end
  return nil
end

local function saveLastStableBuild(front, back, setNames, mundus, cpIds)
  local sv = R and R.SV
  if type(sv) ~= "table" then return end
  if countNonZeroIds(front) < 5 or countNonZeroIds(back) < 5 then return end
  if type(setNames) ~= "table" or #setNames < 2 then return end
  if type(mundus) ~= "string" or mundus == "" then return end
  if type(cpIds) ~= "table" or #cpIds < 8 then return end
  sv.lastStableBuild = {
    front = { front[1], front[2], front[3], front[4], front[5], front[6] },
    back = { back[1], back[2], back[3], back[4], back[5], back[6] },
    sets = setNames,
    mundus = mundus,
    cpIds = cpIds,
  }
end

local function championIdsForFingerprint(list)
  local ids = {}
  if type(list) ~= "table" then return ids end
  for _, cp in ipairs(list) do
    local id = tonumber(type(cp) == "table" and cp.id or cp) or 0
    if id > 0 then
      local cKey = type(cp) == "table" and cp.constellation or nil
      -- Craft capture flickers (Steed's Blessing etc.) and is not dummy DPS.
      if cKey ~= "craft" then
        ids[#ids + 1] = id
      end
    end
  end
  return ids
end

local function buildFingerprintParts(session, championList)
  -- Build ID = bars + sets + Mundus + Warfare/Fitness CP ids ONLY.
  -- Food, potions, Major/Minor, attributes, and Craft CP are excluded.
  -- Gap-fill zeros/empties from start snap then last-stable. Never union extras
  -- (a flaky extra set/CP id was minting a new hash on the next dummy).
  local front = barSlotIds(session, "Front")
  local back = barSlotIds(session, "Back")
  local startB = session and session.buildStart
  local endB = session and (session.buildEnd or session.build)
  local stable = lastStableBuild()
  if type(startB) == "table" then
    front = mergeBarSlotIds(front, barSlotIdsFromBuild(startB, "front"))
    back = mergeBarSlotIds(back, barSlotIdsFromBuild(startB, "back"))
  end
  if type(endB) == "table" and endB ~= startB then
    front = mergeBarSlotIds(front, barSlotIdsFromBuild(endB, "front"))
    back = mergeBarSlotIds(back, barSlotIdsFromBuild(endB, "back"))
  end
  if type(stable) == "table" then
    front = mergeBarSlotIds(front, stable.front)
    back = mergeBarSlotIds(back, stable.back)
  end
  local setNames = {}
  local function addSetName(n)
    local s = canonicalizeSetName(n)
    if s ~= "" then setNames[#setNames + 1] = s end
  end
  if session and type(session.equippedSets) == "table" then
    for _, n in ipairs(session.equippedSets) do addSetName(n) end
  end
  -- Only fill a sparse live list. A complete 2+ set read is authoritative
  -- (union of Perfected vs not / extra names was the 5-minute drift).
  if #setNames < 2 then
    if type(startB) == "table" and type(startB.sets) == "table" then
      for _, n in ipairs(startB.sets) do
        addSetName(type(n) == "table" and n.name or n)
      end
    end
    if #setNames < 2 and type(endB) == "table" and type(endB.sets) == "table" then
      for _, n in ipairs(endB.sets) do
        addSetName(type(n) == "table" and n.name or n)
      end
    end
    if #setNames < 2 and type(stable) == "table" and type(stable.sets) == "table" then
      for _, n in ipairs(stable.sets) do addSetName(n) end
    end
  end
  table.sort(setNames)
  do
    local uniq, prev = {}, nil
    for _, s in ipairs(setNames) do
      if s ~= prev then uniq[#uniq + 1] = s; prev = s end
    end
    setNames = uniq
  end
  local cpIds = {}
  local seenCp = {}
  local function addCp(id)
    id = tonumber(id) or 0
    if id > 0 and not seenCp[id] then
      seenCp[id] = true
      cpIds[#cpIds + 1] = id
    end
  end
  for _, id in ipairs(championIdsForFingerprint(championList)) do addCp(id) end
  -- Fill holes only when the live bar is short
  if #cpIds < 8 then
    if type(startB) == "table" then
      for _, id in ipairs(championIdsForFingerprint(startB.champion)) do addCp(id) end
    end
    if #cpIds < 8 and type(endB) == "table" then
      for _, id in ipairs(championIdsForFingerprint(endB.champion)) do addCp(id) end
    end
    if #cpIds < 8 and type(stable) == "table" and type(stable.cpIds) == "table" then
      for _, id in ipairs(stable.cpIds) do addCp(id) end
    end
  end
  cpIds = sortedIdList(cpIds)
  local mundus = canonicalMundusName(session and session.mundus)
    or canonicalMundusName(type(startB) == "table" and startB.mundus)
    or canonicalMundusName(type(endB) == "table" and endB.mundus)
    or ""
  if mundus == "" and type(stable) == "table" then
    mundus = canonicalMundusName(stable.mundus) or ""
  end
  mundus = string.lower(mundus)
  saveLastStableBuild(front, back, setNames, mundus, cpIds)
  local parts = {
    "F:" .. table.concat(front, ","),
    "B:" .. table.concat(back, ","),
    "S:" .. table.concat(setNames, ","),
    "M:" .. mundus,
    "C:" .. table.concat(cpIds, ","),
  }
  return table.concat(parts, "|"), setNames, cpIds
end

local function fingerprintLabel(session, setNames, championList)
  local setsShort = {}
  for i = 1, math.min(2, #(setNames or {})) do
    local n = setNames[i]
    -- title-ish from stored lower names
    if session and type(session.equippedSets) == "table" then
      n = tostring(session.equippedSets[i] or n)
    end
    setsShort[#setsShort + 1] = displayName(n, 18)
  end
  local mundus = session and session.mundus
  local cpN = championList and #championList or 0
  local bits = {}
  if #setsShort > 0 then bits[#bits + 1] = table.concat(setsShort, " / ") end
  if mundus and mundus ~= "" then bits[#bits + 1] = mundus end
  if cpN > 0 then bits[#bits + 1] = string.format("%d Champion stars", cpN) end
  if #bits == 0 then return "Build (incomplete snapshot)" end
  return table.concat(bits, " · ")
end

local function captureSessionBuild(session, phase)
  if not session then return nil end
  phase = phase or "end"
  local champion = collectSlottedChampionSkills(12)
  -- Union with start-snapshot CP so intermittent console misses don't change ID
  if phase == "end" and type(session.buildStart) == "table"
      and type(session.buildStart.champion) == "table" then
    local seen = {}
    for _, cp in ipairs(champion) do
      local id = tonumber(cp.id) or 0
      if id > 0 then seen[id] = true end
    end
    for _, cp in ipairs(session.buildStart.champion) do
      local id = tonumber(cp and cp.id) or 0
      if id > 0 and not seen[id] then
        champion[#champion + 1] = cp
        seen[id] = true
      end
    end
  end
  local canon, setNames = buildFingerprintParts(session, champion)
  local fp = simpleHashHex(canon)
  local label = fingerprintLabel(session, setNames, champion)
  local fpParts = { f = "", b = "", s = "", m = "", c = "" }
  for piece in string.gmatch(tostring(canon), "[^|]+") do
    local k = string.sub(piece, 1, 1)
    if k == "F" then fpParts.f = piece
    elseif k == "B" then fpParts.b = piece
    elseif k == "S" then fpParts.s = piece
    elseif k == "M" then fpParts.m = piece
    elseif k == "C" then fpParts.c = piece end
  end
  session.buildFingerprintCanon = canon
  session.buildFpParts = fpParts
  local profile = getActiveContentProfile()

  local function snapBars(barLabel, sideKey)
    local slots = {}
    local startSlots = nil
    if type(session.buildStart) == "table" and type(session.buildStart.bars) == "table" then
      startSlots = session.buildStart.bars[sideKey]
    end
    local startBySlot = {}
    if type(startSlots) == "table" then
      for _, s in ipairs(startSlots) do
        startBySlot[tonumber(s.slot) or 0] = s
      end
    end
    -- Always 6 entries in slot order 3..8 so fingerprints cannot shift when a slot misses
    for slot = 3, 8 do
      local entry = nil
      if type(session.slottedAbilityBySlot) == "table" then
        entry = session.slottedAbilityBySlot[barLabel .. ":" .. slot]
      end
      local id = (type(entry) == "table" and tonumber(entry.id)) or 0
      local name = (type(entry) == "table" and entry.name) or ""
      if id <= 0 and type(startBySlot[slot]) == "table" then
        id = tonumber(startBySlot[slot].id) or 0
        if name == "" then name = startBySlot[slot].name or "" end
      end
      slots[#slots + 1] = { slot = slot, id = id, name = name or "" }
    end
    return slots
  end

  local stats = nil
  if phase == "start" and type(session.playerStatsStart) == "table" then
    stats = session.playerStatsStart
  elseif type(session.playerStatsEnd) == "table" then
    stats = session.playerStatsEnd
  elseif type(session.playerStats) == "table" then
    stats = session.playerStats
  end

  local attrs = (stats and stats.attributes) or {}
  local food = captureActiveFood()
  local build = {
    fingerprint = fp,
    fingerprintLabel = label,
    fingerprintCanon = canon,
    fpParts = fpParts,
    profileId = profile.id,
    phase = phase,
    wallClock = (type(os) == "table" and type(os.time) == "function") and os.time() or 0,
    bars = {
      front = snapBars("Front", "front"),
      back = snapBars("Back", "back"),
    },
    sets = {},
    mundus = canonicalMundusName(session.mundus)
      or canonicalMundusName(stats and stats.mundus)
      or canonicalMundusName(session.buildStart and session.buildStart.mundus)
      or nil,
    food = food,
    champion = champion,
    attributes = {
      magicka = attrs.magicka,
      health = attrs.health,
      stamina = attrs.stamina,
    },
  }
  if food and food ~= "" then
    session.food = food
  end
  if type(session.equippedSets) == "table" then
    for _, n in ipairs(session.equippedSets) do
      build.sets[#build.sets + 1] = { name = tostring(n) }
    end
  end
  -- Stable core key (bars/sets/Mundus, no CP) for experiments + A/B pairing
  -- Slot-aligned 3..8 (same order as fingerprint) — compact ipairs used to shift IDs
  local frontIds = barSlotIdsFromBuild(build, "front")
  local backIds = barSlotIdsFromBuild(build, "back")
  local setParts = {}
  for _, n in ipairs(build.sets) do
    local s = canonicalizeSetName((type(n) == "table" and n.name) or n)
    if s ~= "" then setParts[#setParts + 1] = s end
  end
  table.sort(setParts)
  build.coreKey = table.concat({
    "F:" .. table.concat(frontIds, ","),
    "B:" .. table.concat(backIds, ","),
    "S:" .. table.concat(setParts, ","),
    "M:" .. string.lower(tostring(build.mundus or "")),
  }, "|")
  return build
end
M.CaptureSessionBuild = captureSessionBuild
M.GetActiveContentProfile = getActiveContentProfile
M.FormatProfileBadge = formatProfileBadge
M.ConfidenceChip = confidenceChip
M.CONFIDENCE = CONFIDENCE

local function penCapNote(penValue)
  local p = tonumber(penValue) or 0
  local target = PEN_TARGET_LIGHT
  if p >= target then
    local over = math.floor(p - target + 0.5)
    if over > 50 then
      return string.format("|c66FF88@cap|r |cAAAAAA(+%s)|r", fmtInt(over))
    end
    return "|c66FF88@cap|r"
  end
  local short = math.floor(target - p + 0.5)
  local pct = math.min(1, p / target)
  return string.format("|cFFCC66%0.0f%%|r |cAAAAAA(−%s)|r", pct * 100, fmtInt(short))
end

-- Structured rows for UI: { label, sheet, temp, note, kind }
-- Sheet = full with buffs; Temp = Sheet − API base (food/skills/sets) — not stacked twice.
local function buildStatSnapRows(snap, maxRows)
  maxRows = tonumber(maxRows) or 16
  local rows = {}
  if not snap or type(snap) ~= "table" then
    return { { label = "(stats unavailable)", sheet = "", temp = "", note = "", kind = "msg" } }
  end
  local b, c = snap.base or {}, snap.buffed or {}
  local canDelta = snap.canDelta == true
  local function hasAnyDelta()
    local keys = {
      "health", "magicka", "stamina", "penPhysical", "penSpell",
      "weaponDamage", "spellDamage", "physResist", "spellResist",
      "magickaRecovery", "healthRecovery", "staminaRecovery",
    }
    for _, k in ipairs(keys) do
      if math.abs((tonumber(c[k]) or 0) - (tonumber(b[k]) or 0)) >= 1 then return true end
    end
    if math.abs((tonumber(c.critChance) or 0) - (tonumber(b.critChance) or 0)) >= 0.002 then return true end
    return false
  end
  if not canDelta then canDelta = hasAnyDelta() end

  local function dltInt(bv, cv)
    bv, cv = tonumber(bv), tonumber(cv)
    if bv == nil or cv == nil then return "—" end
    local d = math.floor(cv - bv + 0.5)
    if math.abs(d) < 1 then return "—" end
    if d > 0 then return string.format("|c66FF88+%s|r", fmtInt(d)) end
    return string.format("|cFF8888%s|r", fmtInt(d))
  end
  local function dltPct(bv, cv)
    bv, cv = tonumber(bv), tonumber(cv)
    if bv == nil or cv == nil then return "—" end
    local d = (cv - bv) * 100
    if math.abs(d) < 0.15 then return "—" end
    if d > 0 then return string.format("|c66FF88+%0.1f%%|r", d) end
    return string.format("|cFF8888%0.1f%%|r", d)
  end
  -- Columns: TOTAL (fight with) | FROM BUFFS (delta in TOTAL) | UNBUFFED
  -- Never interpret as TOTAL = UNBUFFED + FROM BUFFS as a second stack.
  local function add(label, sheetTxt, bonusTxt, baseTxt, note, kind)
    rows[#rows + 1] = {
      label = label,
      sheet = sheetTxt or "", -- TOTAL
      temp = bonusTxt or "",  -- FROM BUFFS (+delta)
      base = baseTxt or "",   -- UNBUFFED
      note = note or "",
      kind = kind or "stat",
    }
  end
  local function baseInt(bv)
    if bv == nil or tonumber(bv) == nil then return "—" end
    bv = tonumber(bv) or 0
    if bv <= 0 then return "—" end
    return fmtInt(bv)
  end
  local function basePct(bv)
    if bv == nil or tonumber(bv) == nil then return "—" end
    bv = tonumber(bv) or 0
    if bv <= 0 then return "—" end
    return string.format("%0.1f%%", bv * 100)
  end

  local critC = tonumber(c.critChance) or 0
  local critB = tonumber(b.critChance)
  if critC < 0.01 then critC = critFractionFromRatings(c.critWeapon, c.critSpell) end
  if critB == nil or critB < 0.01 then
    if b.critWeapon ~= nil or b.critSpell ~= nil then
      critB = critFractionFromRatings(b.critWeapon, b.critSpell)
    else
      critB = nil
    end
  end

  -- Crit damage often stored as fraction or percent
  local function critDmgPct(v)
    v = tonumber(v) or 0
    if v <= 0 then return 0 end
    if v <= 2 then return v * 100 end -- 0.5 → 50%, 1.5 → 150%
    if v <= 100 then return v end
    return v
  end
  local critDmgC = critDmgPct(c.critDamage)
  local critDmgB = critDmgPct(b.critDamage)
  -- ESO base crit dmg is often ~50%; if API empty, leave blank
  local critDmgSheet = (critDmgC > 0) and string.format("%0.0f%%", critDmgC) or "—"
  local critDmgBase = (critDmgB > 0) and string.format("%0.0f%%", critDmgB) or "—"

  local penP, penS = tonumber(c.penPhysical) or 0, tonumber(c.penSpell) or 0

  add("Crit chance", string.format("%0.1f%%", critC * 100), dltPct(critB, critC), basePct(critB), "", "stat")
  add("Crit dmg", critDmgSheet, (critDmgC > 0 and critDmgB > 0) and dltInt(critDmgB, critDmgC) or "—", critDmgBase, "", "stat")
  add("Pen phys", fmtInt(penP), dltInt(b.penPhysical, c.penPhysical), baseInt(b.penPhysical), penCapNote(penP), "pen")
  add("Pen spell", fmtInt(penS), dltInt(b.penSpell, c.penSpell), baseInt(b.penSpell), penCapNote(penS), "pen")
  add("Weapon dmg", fmtInt(c.weaponDamage or c.power or 0), dltInt(b.weaponDamage or b.power, c.weaponDamage or c.power), baseInt(b.weaponDamage or b.power), "", "stat")
  add("Spell dmg", fmtInt(c.spellDamage or 0), dltInt(b.spellDamage, c.spellDamage), baseInt(b.spellDamage), "", "stat")
  local foodNote = ""
  if type(snap.food) == "string" and snap.food ~= "" then
    foodNote = "food in TOTAL"
  end
  add("Health", fmtInt(c.health or 0), dltInt(b.health, c.health), baseInt(b.health), foodNote, "stat")
  add("Magicka", fmtInt(c.magicka or 0), dltInt(b.magicka, c.magicka), baseInt(b.magicka), foodNote, "stat")
  add("Stamina", fmtInt(c.stamina or 0), dltInt(b.stamina, c.stamina), baseInt(b.stamina), foodNote, "stat")
  add("HP recovery", fmtInt(c.healthRecovery or 0), dltInt(b.healthRecovery, c.healthRecovery), baseInt(b.healthRecovery), "", "stat")
  add("Mag recovery", fmtInt(c.magickaRecovery or 0), dltInt(b.magickaRecovery, c.magickaRecovery), baseInt(b.magickaRecovery), "", "stat")
  add("Stam recovery", fmtInt(c.staminaRecovery or 0), dltInt(b.staminaRecovery, c.staminaRecovery), baseInt(b.staminaRecovery), "", "stat")
  add("Phys resist", fmtInt(c.physResist or 0), dltInt(b.physResist, c.physResist), baseInt(b.physResist), "", "stat")
  add("Spell resist", fmtInt(c.spellResist or 0), dltInt(b.spellResist, c.spellResist), baseInt(b.spellResist), "", "stat")

  local attrs = snap.attributes or {}
  if attrs.magicka or attrs.health or attrs.stamina then
    add("Attr points", string.format("Mag %s · HP %s · Stam %s",
      tostring(attrs.magicka or 0),
      tostring(attrs.health or 0),
      tostring(attrs.stamina or 0)), "", "", "", "attr")
  end

  while #rows > maxRows do table.remove(rows) end
  return rows, canDelta
end

-- Compact string lines (fallback / thin displays)
local function formatStatSnapLines(snap, maxLines)
  maxLines = tonumber(maxLines) or 12
  local rows, canDelta = buildStatSnapRows(snap, maxLines - 1)
  local lines = {}
  lines[1] = canDelta
    and "|cB0A890Stat          Sheet      Temp|r"
    or  "|cB0A890Stat          Sheet|r  |c888888(temp n/a)|r"
  for _, r in ipairs(rows) do
    local left = string.format("%-10s  %8s", string.sub(r.label or "", 1, 10), r.sheet or "")
    if canDelta and r.temp and r.temp ~= "" then
      left = left .. "  " .. r.temp
    end
    if r.note and r.note ~= "" then
      left = left .. "  " .. r.note
    end
    lines[#lines + 1] = left
    if #lines >= maxLines then break end
  end
  return lines
end

local function formatStatLegendLine()
  return "TOTAL = end-of-fight (combat buffs on)  ·  FROM BUFFS = delta inside TOTAL  ·  UNBUFFED = API without temp bonuses (— if unreliable). Sheet at rest is lower."
end

local function formatStatProvenance(session, snap, phase)
  -- phase: "end" | "start" | "live"
  phase = phase or "end"
  local parts = {}
  local count = historyCount()
  local fightNo = nil
  if session and count > 0 then
    -- Prefer current history offset when viewing history
    fightNo = fightNumberFromOffset(historyOffset or 0, count)
  end
  if fightNo then
    parts[#parts + 1] = string.format("@parse #%d", fightNo)
  end
  if phase == "live" then
    parts[#parts + 1] = "live"
  elseif phase == "start" then
    parts[#parts + 1] = "fight start"
  else
    parts[#parts + 1] = "fight end"
  end
  local wall = snap and tonumber(snap.wallClock) or 0
  if wall > 0 and type(os) == "table" and type(os.date) == "function" then
    local ok, t = pcall(os.date, "%H:%M", wall)
    if ok and t then parts[#parts + 1] = tostring(t) end
  end
  return table.concat(parts, " · ")
end

local function critBalanceCue(snap, session)
  if not snap or type(snap) ~= "table" then return "" end
  local c = snap.buffed or {}
  local critC = tonumber(c.critChance) or 0
  if critC < 0.01 then critC = critFractionFromRatings(c.critWeapon, c.critSpell) end
  local critDmg = tonumber(c.critDamage) or 0
  if critDmg > 0 and critDmg <= 2 then critDmg = critDmg * 100 end
  local profile = getActiveContentProfile()
  local penP = tonumber(c.penPhysical) or 0
  local penS = tonumber(c.penSpell) or 0
  local penHi = math.max(penP, penS)
  local resist = tonumber(profile.bossResist) or PEN_TARGET_LIGHT
  local penBit = ""
  if penHi >= resist then
    penBit = string.format("  ·  pen at/over %s ref (%s)", fmtInt(resist), profile.shortLabel or "trial-prep")
  end
  -- Phase 2.5.1: prefer exposure one-liner when samples exist
  local cachedCoach = session and getSessionCoach(session)
  local exp = session and (session.critDmgExposure or (cachedCoach and cachedCoach.waste and cachedCoach.waste.critDmg and cachedCoach.waste.critDmg.exposure))
  if type(exp) == "table" and (tonumber(exp.samples) or 0) > 0 and exp.confidence ~= CONFIDENCE.INSUFFICIENT then
    local avg = tonumber(exp.avgSheetCritPct) or critDmg
    local over = (tonumber(exp.overcapExposure) or 0) * 100
    local capU = tonumber(exp.capUptime) or 0
    if over >= 0.5 or capU >= 0.25 then
      return string.format(
        "Crit-dmg exposure: avg %0.0f%% · at/over cap %s · overcap ~%0.1f%%  %s%s",
        avg, fmtPct(capU), over, confidenceChip(exp.confidence or CONFIDENCE.ESTIMATED), penBit
      )
    end
    return string.format(
      "Crit-dmg exposure: avg %0.0f%% (under ceiling %0.0f%%)  %s%s",
      avg, tonumber(exp.ceilingPct) or 125, confidenceChip(exp.confidence or CONFIDENCE.ESTIMATED), penBit
    )
  end
  if critDmg <= 0 then
    return string.format("Crit chance %0.1f%%%s", critC * 100, penBit)
  end
  local cue
  if critC >= 0.65 and critDmg < 55 then
    cue = "high crit chance · crit damage may lag"
  elseif critC < 0.50 and critDmg >= 70 then
    cue = "crit damage stacked · chance still low"
  elseif profile.assumeMajorForce and critDmg >= 115 then
    cue = "trial-prep: watch crit-damage overcap with group Force"
  else
    cue = "crit chance vs crit damage"
  end
  return string.format("%s  ·  %0.1f%% crit  ·  %0.0f%% crit damage%s", cue, critC * 100, critDmg, penBit)
end

local function buildKeySelfBuffStrip(session, maxItems)
  maxItems = tonumber(maxItems) or 6
  local out = {}
  if not session or type(session.buffs) ~= "table" then return out end
  local dur = tonumber(session.durationMs) or 0
  if dur <= 0 then return out end
  local byKey = {}
  for _, b in pairs(session.buffs) do
    if type(b) == "table" and b.name then
      local low = string.lower(tostring(b.name))
      for _, k in ipairs(KEY_SELF_BUFF_KEYS) do
        if string.find(low, k.key, 1, true) then
          local active = tonumber(b.activeMs) or 0
          local up = active / dur
          local prev = byKey[k.key]
          if not prev or up > (prev.uptime or 0) then
            byKey[k.key] = { label = k.label, uptime = up, name = b.name }
          end
        end
      end
    end
  end
  for _, k in ipairs(KEY_SELF_BUFF_KEYS) do
    if byKey[k.key] then
      out[#out + 1] = byKey[k.key]
      if #out >= maxItems then break end
    end
  end
  return out
end

local function buildDashboardModel(session)
  if not session then return nil end
  local totalDamage = tonumber(session.totalDamage) or 0
  local directPct = totalDamage > 0 and ((tonumber(session.directDamage) or 0) / totalDamage) or 0
  local dotPct = totalDamage > 0 and ((tonumber(session.dotDamage) or 0) / totalDamage) or 0
  local weave = type(session.weave) == "table" and session.weave or {}
  local target = truncateText(session.lastTargetName or "Unknown", 48)
  if session.isDummy then target = target .. " *" end
  local gearSets = {}
  if type(session.equippedSets) == "table" then
    for i, name in ipairs(session.equippedSets) do gearSets[i] = name end
  end
  return {
    target = target,
    meta = string.format("%s  |  %s", formatSessionTimestampShort(session), fmtDur(session.durationMs)),
    isDummy = session.isDummy == true,
    avgDps = fmtDps(sessionAvgDps(session)),
    peakDps = fmtDps(sessionPeakDps(session)),
    totalDamage = fmtInt(totalDamage),
    critPct = fmtPct(sessionCritPct(session)),
    directDot = string.format("%s direct  |  %s DoT", fmtPct(directPct), fmtPct(dotPct)),
    weavePct = fmtPct(getWeaveSuccessRatio(session)),
    laHits = tostring(sessionLaHits(session)),
    weaveDetail = string.format(
      "Missed %d  |  Late %d  |  Fast %d",
      tonumber(weave.missedCount) or 0,
      tonumber(weave.lateCount) or 0,
      tonumber(weave.tooFastCount) or 0
    ),
    events = fmtInt(session.hitCount or session.eventCount),
    topSkills = buildTopSkillRows(session, 5),
    frontBar = collectBarSlots(session, "Front"),
    backBar = collectBarSlots(session, "Back"),
    gearSets = gearSets,
    sparkBuckets = denseSparkBuckets(session),
    contrib = buildDamageContribution(session),
  }
end

-- Menu-side weave summary (mirrors overlay weaveSummary; no SV coupling).
local function weaveSummaryLocal(session)
  local w = (session and type(session.weave) == "table") and session.weave or {}
  local intervals = {}
  if type(w.laIntervals) == "table" then
    for _, d in ipairs(w.laIntervals) do
      if d and d > 0 then intervals[#intervals + 1] = d end
    end
  end
  local n = #intervals
  local laCount = tonumber(w.laCount) or 0
  local durMs = tonumber(session and session.durationMs) or 0
  local laPerSec = (durMs > 0) and (laCount / (durMs / 1000)) or 0
  local late = tonumber(w.lateCount) or 0
  local missed = tonumber(w.missedCount) or 0
  local onTime = tonumber(w.onTimeCount) or 0
  local tooFast = tonumber(w.tooFastCount) or 0
  local fastSkill = tonumber(w.fastSkillPresses) or tooFast
  if n == 0 then
    return {
      laHits = laCount, laPerSec = laPerSec, avgGap = 0, bestGap = 0, worstGap = 0,
      late = late, missed = missed, onTime = onTime, fastSkillPresses = fastSkill, samples = 0,
    }
  end
  table.sort(intervals)
  local sum, best, worst = 0, nil, 0
  for _, d in ipairs(intervals) do
    sum = sum + d
    if (not best) and d >= 250 then best = d end
    if d > worst then worst = d end
  end
  if not best then best = intervals[1] end
  return {
    laHits = laCount, laPerSec = laPerSec, avgGap = sum / n, bestGap = best or 0, worstGap = worst or 0,
    late = late, missed = missed, onTime = onTime, fastSkillPresses = fastSkill, samples = n,
  }
end

-- Skill press → next skill press, minus the 1s cooldown.
-- Under 900ms is an early press (the button beat the cast). Over 1800ms is a stall.
-- Neither goes into the median. Returns band, r, g, b.
-- Fields on M, not new chunk locals (MenuShell is already past the 200-local cap).
function M.CastPaceBand(gap)
  gap = tonumber(gap)
  if not gap or gap <= 0 then return nil end
  if gap < 900 then return "early", 0.40, 0.65, 0.95 end
  if gap > 1800 then return "stall", 0.95, 0.35, 0.30 end
  local lost = gap - 1000
  if lost < 0 then lost = 0 end
  if lost < 40 then return "tight", 0.35, 0.92, 0.45 end
  if lost < 80 then return "ok", 0.95, 0.78, 0.30 end
  return "late", 0.95, 0.35, 0.30
end

function M.SkillCastPace(session)
  local lost, early, stalls = {}, 0, 0
  local tl = session and session.weave and session.weave.timeline
  if type(tl) ~= "table" then
    return { medianLostMs = 0, totalLostMs = 0, samples = 0, early = 0, stalls = 0 }
  end
  local prev = nil
  for i = 1, #tl do
    local item = tl[i]
    if type(item) == "table" and item.kind ~= "la" and item.kind ~= "light"
        and item.kind ~= "swap" and item.kind ~= "barswap" and item.kind ~= "postchannel" then
      local t = tonumber(item.tMs)
      local isChannel = item.kind == "channel"
          or string.lower(tostring(item.result or "")) == "channel"
      if prev and prev.t and t and not prev.channel then
        local gap = t - prev.t
        local band = M.CastPaceBand(gap)
        if band == "early" then
          early = early + 1
        elseif band == "stall" then
          stalls = stalls + 1
        elseif band then
          local waste = gap - 1000
          if waste < 0 then waste = 0 end
          lost[#lost + 1] = waste
        end
      end
      if t then prev = { t = t, channel = isChannel } else prev = nil end
    end
  end
  local n = #lost
  local total = 0
  for i = 1, n do total = total + lost[i] end
  local median = 0
  if n > 0 then
    table.sort(lost)
    local mid = math.floor(n / 2)
    if n % 2 == 1 then median = lost[mid + 1]
    else median = (lost[mid] + lost[mid + 1]) / 2 end
  end
  return {
    medianLostMs = median,
    totalLostMs = total,
    samples = n,
    early = early,
    stalls = stalls,
  }
end

-- Simple burst/drop windows from buckets (menu-local; ignore windows approx).
local function analyzeBucketsLocal(session)
  local peaks, dips, candidates = {}, {}, {}
  if not session or type(session.buckets) ~= "table" then return peaks, dips end
  for idx, b in pairs(session.buckets) do
    if type(b) == "table" then
      candidates[#candidates + 1] = {
        idx = tonumber(idx) or 0,
        dmg = tonumber(b.dmg) or 0,
        skills = b.skills,
      }
    end
  end
  table.sort(candidates, function(a, b) return a.dmg > b.dmg end)
  for i = 1, math.min(3, #candidates) do peaks[i] = candidates[i] end
  table.sort(candidates, function(a, b) return a.dmg < b.dmg end)
  local found = 0
  for i = 1, #candidates do
    if candidates[i].dmg > 0 then
      found = found + 1
      dips[found] = candidates[i]
      if found >= 3 then break end
    end
  end
  return peaks, dips
end

local function bucketTopSkillName(session, bucket, bms)
  if not bucket or type(bucket.skills) ~= "table" then return "-" end
  local bestId, bestDmg = nil, -1
  for id, dmg in pairs(bucket.skills) do
    local v = tonumber(dmg) or 0
    if v > bestDmg then bestDmg = v bestId = id end
  end
  if not bestId then return "-" end
  local abilityId = tonumber(bestId) or 0
  local name = nil
  if session and type(session.skills) == "table" then
    local sk = session.skills[abilityId] or session.skills[bestId]
    if type(sk) == "table" then name = sk.name end
  end
  if not name or name == "" then name = getAbilityName(abilityId) end
  local dps = (bms > 0) and (bestDmg / (bms / 1000)) or 0
  return string.format("%s (%s)", truncateText(name, 24), fmtDps(dps))
end

-- Full Summary model for dense Overview (parity target with overlay Summary page).
local function buildSummaryModel(session)
  if not session then return nil end
  local dur = tonumber(session.durationMs) or 0
  local total = tonumber(session.totalDamage) or 0
  local direct = tonumber(session.directDamage) or 0
  local dot = tonumber(session.dotDamage) or 0
  local hits = tonumber(session.hitCount) or 0
  local crits = tonumber(session.critCount) or 0
  local directPct = total > 0 and (direct / total) or 0
  local dotPct = total > 0 and (dot / total) or 0
  local critPct = hits > 0 and (crits / hits) or 0
  local setDamage = 0
  if type(session.sets) == "table" then
    for _, ps in pairs(session.sets) do
      if type(ps) == "table" then setDamage = setDamage + (tonumber(ps.dmg) or 0) end
    end
  end
  local setPct = total > 0 and (setDamage / total) or 0
  local peaks, dips = analyzeBucketsLocal(session)
  local bms = bucketMs()
  local peakDps = 0
  if peaks[1] then peakDps = (tonumber(peaks[1].dmg) or 0) / (bms / 1000) end
  if peakDps <= 0 then peakDps = sessionPeakDps(session) end
  local ws = weaveSummaryLocal(session)
  local weaveSuccess = getWeaveSuccessRatio(session)
  local epm = (dur > 0) and ((hits / (dur / 1000)) * 60) or 0
  local totalHeal = tonumber(session.totalHealing) or 0
  local effectiveHeal = tonumber(session.effectiveHealing) or totalHeal
  local overHeal = math.max(0, totalHeal - effectiveHeal)
  local healPerSec = (dur > 0) and (effectiveHeal / (dur / 1000)) or 0
  local overHealPct = (totalHeal > 0) and (overHeal / totalHeal) or 0
  local sets = {}
  if type(session.sets) == "table" then
    local arr = {}
    for _, ps in pairs(session.sets) do
      if type(ps) == "table" then arr[#arr + 1] = ps end
    end
    table.sort(arr, function(a, b) return (tonumber(a.dmg) or 0) > (tonumber(b.dmg) or 0) end)
    for i = 1, math.min(3, #arr) do
      local ps = arr[i]
      local dmg = tonumber(ps.dmg) or 0
      local phits = tonumber(ps.hits) or 0
      local share = total > 0 and (dmg / total) or 0
      local dps = dur > 0 and (dmg / (dur / 1000)) or 0
      local crit = phits > 0 and ((tonumber(ps.crit) or 0) / phits) or 0
      local dotp = dmg > 0 and ((tonumber(ps.dot) or 0) / dmg) or 0
      local kind = (dotp > 0.95) and "DoT" or (dotp < 0.05) and "Direct" or "Mixed"
      sets[i] = {
        name = ps.name or "?",
        line = string.format("%s   %s   %s share   crit %s   %s DPS",
          truncateText(ps.name or "?", 40), fmtInt(dmg), fmtPct(share), fmtPct(crit), fmtDps(dps)),
        share = share,
      }
    end
  end
  local topSkills = {}
  if type(session.skills) == "table" then
    local arr = {}
    for id, sk in pairs(session.skills) do
      if type(sk) == "table" then
        arr[#arr + 1] = {
          id = tonumber(sk.id) or tonumber(id) or 0,
          name = sk.name,
          dmg = tonumber(sk.dmg) or 0,
          hits = tonumber(sk.hits) or 0,
          crit = tonumber(sk.crit) or 0,
          max = tonumber(sk.max) or 0,
        }
      end
    end
    table.sort(arr, function(a, b) return a.dmg > b.dmg end)
    local topDmg = (#arr > 0) and (tonumber(arr[1].dmg) or 0) or 0
    for i = 1, math.min(5, #arr) do
      local s = arr[i]
      local dmg = s.dmg
      local shits = s.hits
      local share = total > 0 and (dmg / total) or 0
      -- Bar length relative to #1 skill (not total fight) so impact is readable
      local relShare = (topDmg > 0) and (dmg / topDmg) or 0
      local dps = dur > 0 and (dmg / (dur / 1000)) or 0
      local crit = shits > 0 and ((s.crit or 0) / shits) or 0
      local name = s.name
      if not name or name == "" then name = getAbilityName(s.id) end
      local bar = getSkillBar(session, s.id)
      local source, sourceChip = classifyDamageSource(session, s.id, name, bar)
      topSkills[i] = {
        name = name,
        icon = resolveSkillIcon(session, s.id, name),
        bar = bar,
        source = source,
        sourceChip = sourceChip,
        share = share,
        relShare = relShare,
        sub = string.format("%s · %s DPS · %s share · crit %s",
          source, fmtDps(dps), fmtPct(share), fmtPct(crit)),
      }
    end
  end
  local function bucketLine(title, b)
    if not b then return title .. "  —" end
    local dps = (tonumber(b.dmg) or 0) / (bms / 1000)
    local t0 = (tonumber(b.idx) or 0) * bms
    local t1 = t0 + bms
    -- Single line for side-by-side Burst|Drop columns (no wrap under).
    local topName = bucketTopSkillName(session, b, bms)
    topName = truncateText(topName, 48)
    return string.format("%s  %.0f–%.0fs  %s  ·  %s",
      title, t0 / 1000, t1 / 1000, fmtDps(dps), topName)
  end
  local equipped = ""
  if type(session.equippedSets) == "table" and #session.equippedSets > 0 then
    equipped = table.concat(session.equippedSets, ", ")
  else
    equipped = "(sets unknown)"
  end
  return {
    target = truncateText(session.lastTargetName or "Unknown", 48) .. (session.isDummy and " *" or ""),
    meta = string.format("%s  ·  %s  ·  dummy %s  ·  %s",
      formatSessionTimestampShort(session), fmtDur(dur),
      session.isDummy and "Yes" or "No", truncateText(equipped, 72)),
    kpis = {
      { key = "avg", label = "Fight Avg DPS", value = fmtDps(sessionAvgDps(session)) },
      { key = "peak", label = "Peak 2s DPS", value = fmtDps(peakDps) },
      { key = "total", label = "Fight Total", value = fmtInt(total) },
      { key = "dur", label = "Fight Duration", value = fmtDur(dur) },
      { key = "crit", label = "Crit Rate", value = fmtPct(critPct) },
      { key = "maxhit", label = "Max Hit", value = fmtInt(session.maxHit) },
      { key = "split", label = "Direct vs DoT", value = string.format("%s / %s", fmtPct(directPct), fmtPct(dotPct)) },
      { key = "events", label = "Damage Hits", value = fmtInt(hits) },
      { key = "epm", label = "Hits / Min", value = string.format("%.0f", epm) },
      { key = "weave", label = "Weave Success", value = (ws.samples > 0 or (ws.onTime + ws.late + ws.missed) > 0) and fmtPct(weaveSuccess) or "-" },
      { key = "avglag", label = "Avg LA Gap", value = (ws.samples > 0) and string.format("%.0f ms", ws.avgGap or 0) or "-" },
      { key = "setpct", label = "Set Proc Share", value = fmtPct(setPct) },
      { key = "heal", label = "Total Healing", value = fmtInt(totalHeal) },
      { key = "hps", label = "Effective HPS", value = fmtDps(healPerSec) },
      { key = "overheal", label = "Overheal %", value = fmtPct(overHealPct) },
    },
    rot = {
      { string.format("LA Hits: %d", ws.laHits or 0), string.format("LA/s: %.2f", ws.laPerSec or 0) },
      {
        (ws.samples > 0) and string.format("Avg LA Gap: %.0f ms", ws.avgGap or 0) or "Avg LA Gap: -",
        string.format("Weave Timing: %s", fmtPct(weaveSuccess)),
      },
      {
        (ws.samples > 0) and string.format("Best Gap: %.0f ms", ws.bestGap or 0) or "Best Gap: -",
        (ws.samples > 0) and string.format("Worst Gap: %.0f ms", ws.worstGap or 0) or "Worst Gap: -",
      },
      {
        string.format("Missed: %d | Late: %d", ws.missed or 0, ws.late or 0),
        string.format("Fast Presses: %d", ws.fastSkillPresses or 0),
      },
    },
    spikes = {
      bucketLine("Burst 1", peaks[1]),
      bucketLine("Burst 2", peaks[2]),
      bucketLine("Burst 3", peaks[3]),
    },
    dips = {
      bucketLine("Drop 1", dips[1]),
      bucketLine("Drop 2", dips[2]),
      bucketLine("Drop 3", dips[3]),
    },
    spark = denseSparkBuckets(session),
    sets = sets,
    topSkills = topSkills,
  }
end

local function padRightLocal(s, w)
  s = tostring(s or "")
  if #s >= w then return string.sub(s, 1, w) end
  return s .. string.rep(" ", w - #s)
end

-- Shorten enchant descriptions: "Adds 1742 Maximum Magicka" → "Max Magicka +1742"
local function shortEnchantLocal(desc)
  desc = stripColorLocal(desc)
  desc = desc:gsub("%s+", " ")
  desc = desc:gsub("^Adds%s+", "")
  desc = desc:gsub("^Grants%s+", "")
  desc = desc:gsub("Maximum Magicka", "Max Mag")
  desc = desc:gsub("Maximum Stamina", "Max Stam")
  desc = desc:gsub("Maximum Health", "Max HP")
  desc = desc:gsub("Weapon Damage", "WD")
  desc = desc:gsub("Spell Damage", "SD")
  desc = desc:gsub("Critical Chance", "Crit")
  desc = desc:gsub("Physical Penetration", "Phys Pen")
  desc = desc:gsub("Spell Penetration", "Spell Pen")
  return truncateText(desc, 34)
end

local function buildGearLines(session)
  local lines = {}
  if session and type(session.equippedSets) == "table" and #session.equippedSets > 0 then
    lines[#lines + 1] = "|cC0A060── Sets on this parse ──|r"
    for i, name in ipairs(session.equippedSets) do
      lines[#lines + 1] = string.format("  |c88DDAA%d.|r  %s", i, tostring(name))
    end
    lines[#lines + 1] = ""
  else
    lines[#lines + 1] = "|cAAAAAANo set names captured on this parse snapshot.|r"
    lines[#lines + 1] = ""
  end
  -- Live worn: clear three-column layout (Slot | Item | Enchant)
  if type(GetItemLink) == "function" and type(BAG_WORN) ~= "nil" then
    local slotDefs = {
      { "Head", "EQUIP_SLOT_HEAD" }, { "Shoulders", "EQUIP_SLOT_SHOULDERS" },
      { "Chest", "EQUIP_SLOT_CHEST" }, { "Hands", "EQUIP_SLOT_HAND" },
      { "Waist", "EQUIP_SLOT_WAIST" }, { "Legs", "EQUIP_SLOT_LEGS" },
      { "Feet", "EQUIP_SLOT_FEET" }, { "Neck", "EQUIP_SLOT_NECK" },
      { "Ring 1", "EQUIP_SLOT_RING1" }, { "Ring 2", "EQUIP_SLOT_RING2" },
      { "Front MH", "EQUIP_SLOT_MAIN_HAND" }, { "Front OH", "EQUIP_SLOT_OFF_HAND" },
      { "Back MH", "EQUIP_SLOT_BACKUP_MAIN" }, { "Back OH", "EQUIP_SLOT_BACKUP_OFF" },
    }
    lines[#lines + 1] = "|cC0A060── Live worn (current loadout) ──|r"
    lines[#lines + 1] = string.format("|cAAAAAA%s  %s  %s|r",
      padRightLocal("Slot", 10), padRightLocal("Item", 30), "Enchant")
    lines[#lines + 1] = "|c555555" .. string.rep("─", 78) .. "|r"
    for _, def in ipairs(slotDefs) do
      local slotId = _G[def[2]]
      if type(slotId) == "number" then
        local ok, link = pcall(GetItemLink, BAG_WORN, slotId)
        local name, enchant = "—", "—"
        if ok and link and link ~= "" then
          if type(GetItemLinkName) == "function" then
            local okName, n = pcall(GetItemLinkName, link)
            if okName and n and n ~= "" then
              name = (type(zo_strformat) == "function") and zo_strformat("<<1>>", n) or n
            end
          end
          if type(GetItemLinkEnchantInfo) == "function" then
            local okEi, hasEnchant, enchantName = pcall(GetItemLinkEnchantInfo, link)
            if okEi and hasEnchant and enchantName and enchantName ~= "" then
              enchant = (type(zo_strformat) == "function") and zo_strformat("<<1>>", enchantName) or enchantName
              enchant = stripColorLocal(enchant)
            end
          end
          if (enchant == "—" or enchant == "") and type(GetItemLinkEnchantDescription) == "function" then
            local okE, desc = pcall(GetItemLinkEnchantDescription, link)
            if okE and desc and desc ~= "" then
              enchant = shortEnchantLocal(desc)
            end
          end
        end
        lines[#lines + 1] = string.format("%s  %s  |cB0A080%s|r",
          padRightLocal(def[1], 10),
          padRightLocal(truncateText(name, 30), 30),
          truncateText(enchant, 34))
      end
    end
  end
  return lines
end

-- Colorized timeline tokens (matches overlay legend): green good, gold late, red miss, blue fast.
local function timelineTokenColored(item)
  if not item then return "|cAAAAAA?|r" end
  local kind = item.kind or ""
  if kind == "la" or kind == "light" then
    return "|cAADDFFLA|r"
  end
  local r = string.lower(tostring(item.result or ""))
  local mark, col = "·", "CCCCCC"
  if r == "good" then mark, col = "+", "66FF66"
  elseif r == "late" then mark, col = "~", "FFCC66"
  elseif r == "missed" then mark, col = "x", "FF6666"
  elseif r == "too fast" then mark, col = ">", "66AAFF"
  elseif r == "extra" then mark, col = "*", "CC88FF" end
  local raw = item.skillName or item.label or "?"
  local name = truncateText(raw, 14)
  -- Bar tint on name when known (Front soft green, Back soft blue).
  local bar = item.bar or ""
  local nameCol = "EEEEEE"
  if bar == "Front" then nameCol = "88DDAA"
  elseif bar == "Back" then nameCol = "88AADD" end
  return string.format("|c%s%s|r|c%s%s|r", col, mark, nameCol, name)
end

local function buildTimelineLines(session, maxLines, visibleCharLimit)
  maxLines = tonumber(maxLines) or ROT_TIMELINE_LINES
  visibleCharLimit = tonumber(visibleCharLimit) or 90
  if not session or type(session.weave) ~= "table" or type(session.weave.timeline) ~= "table"
      or #session.weave.timeline == 0 then
    return { "|cAAAAAANo rotation timeline yet — complete a parse with weave tracking.|r" }
  end
  local tokens = {}
  for _, item in ipairs(session.weave.timeline) do
    if item then tokens[#tokens + 1] = timelineTokenColored(item) end
  end
  local lines, cur, curVis = {}, "", 0
  for _, tok in ipairs(tokens) do
    local vis = #stripColorLocal(tok)
    if cur == "" then
      cur, curVis = tok, vis
    elseif curVis + 2 + vis > visibleCharLimit then
      lines[#lines + 1] = cur
      cur, curVis = tok, vis
      if #lines >= maxLines then break end
    else
      cur = cur .. "  " .. tok
      curVis = curVis + 2 + vis
    end
  end
  if cur ~= "" and #lines < maxLines then lines[#lines + 1] = cur end
  if #lines == 0 then lines[1] = "|cAAAAAATimeline empty.|r" end
  return lines
end

local function buildPulseRatios(session, maxBlocks)
  maxBlocks = tonumber(maxBlocks) or PULSE_BLOCKS
  local ratios = {}
  if not session or type(session.weave) ~= "table" or type(session.weave.timeline) ~= "table" then
    return ratios
  end
  local tl = session.weave.timeline
  local n = #tl
  if n <= 0 then return ratios end
  local step = math.max(1, math.ceil(n / maxBlocks))
  for i = 1, n, step do
    local item = tl[i]
    local r = string.lower(tostring(item and item.result or ""))
    local score = 0.35
    if r == "good" then score = 1.0
    elseif r == "late" then score = 0.65
    elseif r == "too fast" then score = 0.45
    elseif r == "missed" then score = 0.15 end
    ratios[#ratios + 1] = score
    if #ratios >= maxBlocks then break end
  end
  return ratios
end

-- Timeline icon chips for Rotation (prefer icons over truncated text names).
local function shortSkillInitials(name)
  name = tostring(name or "")
  name = name:gsub("^Post%-", "")
  local parts = {}
  for w in string.gmatch(name, "[%a']+") do
    parts[#parts + 1] = w
    if #parts >= 3 then break end
  end
  if #parts == 0 then
    local ch = string.upper(string.sub(name, 1, 2))
    return (ch ~= "" and ch) or "·"
  end
  if #parts == 1 then return string.upper(string.sub(parts[1], 1, 2)) end
  local out = ""
  for i = 1, math.min(3, #parts) do
    out = out .. string.upper(string.sub(parts[i], 1, 1))
  end
  return out
end

-- Collect ALL skill presses (no LA) for rotation timeline. Optional page window.
local function collectSkillTimelineEvents(session)
  local events = {}
  if not session or type(session.weave) ~= "table" or type(session.weave.timeline) ~= "table" then
    return events
  end
  for _, item in ipairs(session.weave.timeline) do
    -- Post-channel recovery tokens are weave results, not skill presses.
    if item and item.kind ~= "la" and item.kind ~= "light" and item.kind ~= "swap"
        and item.kind ~= "barswap" and item.kind ~= "postchannel" then
      local abilityId = tonumber(item.abilityId) or 0
      local rawName = item.skillName or item.label or ""
      local name = resolveDisplaySkillName(session, abilityId, rawName, item.slot, item.bar)
      if abilityId <= 0 and session and type(session.skills) == "table" and name and name ~= "" then
        local key = string.lower(name)
        for id, sk in pairs(session.skills) do
          if type(sk) == "table" and sk.name and string.lower(sk.name) == key then
            abilityId = tonumber(sk.id) or tonumber(id) or 0
            break
          end
        end
      end
      local r = string.lower(tostring(item.result or ""))
      local edgeR, edgeG, edgeB = 0.5, 0.5, 0.5
      if r == "good" then edgeR, edgeG, edgeB = 0.35, 0.92, 0.45
      elseif r == "late" then edgeR, edgeG, edgeB = 0.95, 0.78, 0.30
      elseif r == "missed" then edgeR, edgeG, edgeB = 0.95, 0.35, 0.30
      elseif r == "too fast" then edgeR, edgeG, edgeB = 0.40, 0.65, 0.95
      elseif r == "channel" then edgeR, edgeG, edgeB = 0.55, 0.72, 0.88 end
      local bar = item.bar
      if not bar and abilityId > 0 then bar = getSkillBar(session, abilityId) end
      local isUlt = isUltimateAbility(abilityId, session, name)
      local icon = item.icon
      if isBadIconTex(icon) then
        icon = resolveSkillIcon(session, abilityId, name, item.slot, bar)
      end
      events[#events + 1] = {
        icon = icon,
        name = name,
        initials = shortSkillInitials(name),
        result = r,
        edgeR = edgeR, edgeG = edgeG, edgeB = edgeB,
        bar = bar,
        isUltimate = isUlt,
        abilityId = abilityId,
        tMs = tonumber(item.tMs) or nil,
        gapMs = tonumber(item.gapMs),
      }
    end
  end
  return events
end

local function buildTimelineIconEvents(session, maxIcons, pageIndex)
  maxIcons = tonumber(maxIcons) or ROT_TIMELINE_ICONS
  pageIndex = math.max(1, tonumber(pageIndex) or 1)
  local all = collectSkillTimelineEvents(session)
  local total = #all
  if total == 0 then return {}, 0, 1, 0 end
  local pages = math.max(1, math.ceil(total / maxIcons))
  if pageIndex > pages then pageIndex = pages end
  local startI = (pageIndex - 1) * maxIcons + 1
  local events = {}
  for i = startI, math.min(total, startI + maxIcons - 1) do
    events[#events + 1] = all[i]
  end
  return events, total, pages, pageIndex
end

-- Map S (swap) / U (ult) markers onto skill-icon columns by time.
-- Prefer nearest skill tMs on THIS page; show counts (S3) when several map to one icon.
local function buildIconMarkerTags(session, events)
  local tags = {} -- [iconIndex] = display string e.g. "S" "SU" "S3"
  local swapPlaced, ultPlaced = 0, 0
  if type(session) ~= "table" or type(events) ~= "table" or #events == 0 then
    return tags, swapPlaced, ultPlaced
  end
  local pts = session.markers and session.markers.points
  -- Prefer live marker list; fall back to barStats.swaps if points were compacted away
  if type(pts) ~= "table" then pts = {} end
  local n = #events
  local hasTimes = false
  local tMin, tMax = nil, nil
  for i = 1, n do
    local et = tonumber(events[i].tMs)
    if et then
      hasTimes = true
      if not tMin or et < tMin then tMin = et end
      if not tMax or et > tMax then tMax = et end
    end
  end
  -- Pad window so swaps slightly before first / after last skill on page still attach
  local pad = 1500
  if tMin then tMin = tMin - pad end
  if tMax then tMax = tMax + pad end

  local sCount, uCount = {}, {} -- per icon index

  local function placeMarker(mtype, mt)
    local ch = (mtype == "swap") and "S" or "U"
    local idx = nil
    if hasTimes and mt then
      -- Only place markers that fall near this page's time window
      if tMin and tMax and (mt < tMin or mt > tMax) then return end
      local bestDist, bestI = nil, 1
      for i = 1, n do
        local et = tonumber(events[i].tMs)
        if et then
          local d = math.abs(et - mt)
          if not bestDist or d < bestDist then bestDist, bestI = d, i end
        end
      end
      idx = bestI
    end
    if not idx then return end
    if idx < 1 then idx = 1 end
    if idx > n then idx = n end
    if ch == "S" then
      sCount[idx] = (sCount[idx] or 0) + 1
      swapPlaced = swapPlaced + 1
    else
      uCount[idx] = (uCount[idx] or 0) + 1
      ultPlaced = ultPlaced + 1
    end
  end

  for _, p in ipairs(pts) do
    if type(p) == "table" and (p.type == "swap" or p.type == "ult") then
      placeMarker(p.type, tonumber(p.tMs))
    end
  end
  -- If markers.points empty but barStats still has swap times (pre-compact path)
  if swapPlaced == 0 and type(session.barStats) == "table" and type(session.barStats.swaps) == "table" then
    for _, sw in ipairs(session.barStats.swaps) do
      if type(sw) == "table" then placeMarker("swap", tonumber(sw.tMs)) end
    end
  end

  for i = 1, n do
    local sc, uc = sCount[i] or 0, uCount[i] or 0
    if sc > 0 or uc > 0 then
      local s = ""
      if sc == 1 then s = s .. "S"
      elseif sc > 1 then s = s .. "S" .. tostring(sc) end
      if uc == 1 then s = s .. "U"
      elseif uc > 1 then s = s .. "U" .. tostring(uc) end
      tags[i] = s
    end
  end
  return tags, swapPlaced, ultPlaced
end

-- Pattern / coaching insights (Rotation footer + Insights page).
local function buildPatternInsights(session)
  local tips = {}
  if not session then
    return { "Complete a parse to unlock rotation and weave insights." }
  end
  local tl = {}
  if type(session.weave) == "table" and type(session.weave.timeline) == "table" then
    tl = session.weave.timeline
  end

  local missBySkill, afterSwapMiss, lateBySkill, failedCombo = {}, {}, {}, {}
  local lastWasSwap, lastSkill = false, nil
  local totalEvents, lateLate, missMiss = 0, 0, 0
  local lateLateEnd, missMissEnd, totalEnd = 0, 0, 0
  local lateLateEarly, missMissEarly, totalEarly = 0, 0, 0
  local n = #tl
  local endStart = (n > 0) and math.floor(n * 0.80) or 0

  for idx, item in ipairs(tl) do
    if type(item) == "table" then
      local r = string.lower(tostring(item.result or ""))
      local name = item.skillName or item.label or "?"
      local kind = item.kind or ""
      if kind == "swap" or kind == "barswap" or item.barSwap == true then
        lastWasSwap = true
      elseif kind == "skill" or kind == "postchannel" then
        totalEvents = totalEvents + 1
        local isFail = (r == "late" or r == "too fast" or r == "missed")
        if r == "late" then
          lateLate = lateLate + 1
          lateBySkill[name] = (lateBySkill[name] or 0) + 1
        elseif r == "missed" then
          missMiss = missMiss + 1
          missBySkill[name] = (missBySkill[name] or 0) + 1
          if lastWasSwap then afterSwapMiss[name] = (afterSwapMiss[name] or 0) + 1 end
          if lastSkill and lastSkill ~= name then
            local key = lastSkill .. " → " .. name
            failedCombo[key] = (failedCombo[key] or 0) + 1
          end
        elseif r == "too fast" then
          lateLate = lateLate + 1
        end
        -- Early 80% vs last 20% (index-based) for comparative rush detection
        if n > 0 and idx >= endStart then
          totalEnd = totalEnd + 1
          if r == "late" or r == "too fast" then lateLateEnd = lateLateEnd + 1 end
          if r == "missed" then missMissEnd = missMissEnd + 1 end
        else
          totalEarly = totalEarly + 1
          if r == "late" or r == "too fast" then lateLateEarly = lateLateEarly + 1 end
          if r == "missed" then missMissEarly = missMissEarly + 1 end
        end
        lastSkill = name
        lastWasSwap = false
      end
    end
  end

  local function topKey(map)
    local best, cnt = nil, 0
    for k, v in pairs(map) do
      if v > cnt then best, cnt = k, v end
    end
    return best, cnt
  end

  local worstMiss, missN = topKey(missBySkill)
  if worstMiss and missN >= 2 then
    tips[#tips + 1] = string.format(
      "|cFFAA88Pattern:|r Most missed skill: |cFF8888%s|r (%d×). Weave LA before that press.",
      truncateText(worstMiss, 32), missN
    )
  end

  local badCombo, cn = topKey(failedCombo)
  if badCombo and cn >= 2 then
    tips[#tips + 1] = string.format(
      "|cFFAA88Pattern:|r Most failed skill combo: |cFF8888%s|r (%d× misses on the second press). LA between them.",
      truncateText(badCombo, 48), cn
    )
  end

  local swapMiss, sn = topKey(afterSwapMiss)
  if swapMiss and sn >= 2 then
    tips[#tips + 1] = string.format(
      "|cFFAA88Pattern:|r After bar swap you often miss |cFF8888%s|r. Try LA → first skill on the new bar.",
      truncateText(swapMiss, 32)
    )
  end

  local worstLate, lateN = topKey(lateBySkill)
  if worstLate and lateN >= 3 then
    tips[#tips + 1] = string.format(
      "|cFFCC66Pattern:|r Late weaves cluster on |cFFCC66%s|r (%d×). Press LA sooner after that cast.",
      truncateText(worstLate, 32), lateN
    )
  end

  -- Comparative end-rush: last 20% fail rate must be meaningfully worse than first 80%.
  local endFail = (totalEnd > 0) and ((lateLateEnd + missMissEnd) / totalEnd) or 0
  local earlyFail = (totalEarly > 0) and ((lateLateEarly + missMissEarly) / totalEarly) or 0
  if totalEnd >= 6 and totalEarly >= 10 and endFail >= 0.40 and (endFail - earlyFail) >= 0.15 then
    tips[#tips + 1] = string.format(
      "|cFFAA88Pattern:|r Weaves get messier in the |cFFCC66last ~20%%|r (%.0f%% fail vs %.0f%% earlier). Hold rhythm when the dummy is low.",
      endFail * 100, earlyFail * 100
    )
  elseif totalEvents >= 12 and getWeaveSuccessRatio(session) >= 0.85 then
    tips[#tips + 1] = "|c66FF88Insight:|r Timings look solid overall. Watch for red pulse spikes — those are remaining gaps."
  end

  -- DoT uptime coaching — only player-maintained DoTs (not weapon-enchant status procs)
  if type(session.dotTicks) == "table" then
    local function isPlayerSlottedDot(abilityId, name)
      abilityId = tonumber(abilityId) or 0
      if abilityId > 0 and session.slottedAbilityIds and session.slottedAbilityIds[abilityId] then
        return true
      end
      if abilityId > 0 and type(getSkillBar) == "function" then
        local bar = getSkillBar(session, abilityId)
        if bar == "Front" or bar == "Back" then return true end
      end
      -- Name match against bar snapshot skills
      if type(session.skills) == "table" and name then
        local nlow = string.lower(name)
        for id, sk in pairs(session.skills) do
          if type(sk) == "table" and sk.name and string.lower(sk.name) == nlow then
            local bar = getSkillBar(session, tonumber(sk.id) or tonumber(id) or 0)
            if bar == "Front" or bar == "Back" then return true end
          end
        end
      end
      return false
    end

    local worstDot, worstPct, worstId = nil, 1, 0
    local worstProc, worstProcPct = nil, 1
    local durMs = tonumber(session.durationMs) or 0
    for id, entry in pairs(session.dotTicks) do
      local ticks = entry and entry.ticks
      local tickN = tonumber(entry and entry.tickCount) or (type(ticks) == "table" and #ticks) or 0
      if durMs > 0 and (tickN >= 3 or (type(ticks) == "table" and #ticks >= 3)) then
        local up = select(1, estimateDotUptimeEntry(entry, durMs))
        local dname = entry.name or ("DoT " .. tostring(id))
        local aid = tonumber(entry.id) or tonumber(id) or 0
        if isWeaponEnchantStatusDot(dname) or not isPlayerSlottedDot(aid, dname) then
          if up < worstProcPct then worstProcPct, worstProc = up, dname end
        else
          if up < worstPct then worstPct, worstDot, worstId = up, dname, aid end
        end
      end
    end
    if worstDot and worstPct < 0.50 then
      tips[#tips + 1] = string.format(
        "|cAADDFFDoT tip:|r |cFFCC66%s|r only ~%s uptime. If stacks need a full expire, wait the window — early refresh can waste the reapply.",
        truncateText(worstDot, 28), fmtPct(worstPct)
      )
    elseif worstDot and worstPct < 0.65 then
      tips[#tips + 1] = string.format(
        "|cAADDFFDoT tip:|r Maintain |cFFCC66%s|r more carefully (%.0f%% up). Check gaps after bar swaps.",
        truncateText(worstDot, 28), worstPct * 100
      )
    elseif worstProc and worstProcPct < 0.45 then
      -- Stretch-style: enchant status is not a "maintain skill" tip
      tips[#tips + 1] = string.format(
        "|cC0A060Proc tip:|r |cFFCC66%s|r is mostly weapon-enchant / status (not a skill refresh). Weave LA/HA and keep uptime on the weapon that applies it so the enchant fires more often.",
        truncateText(worstProc, 28)
      )
    end
  end

  -- Contribution coaching (only when a non-skill bucket is large)
  local contrib = buildDamageContribution(session)
  if contrib and contrib.total and contrib.total > 0 then
    local setPct = (contrib.buckets.set or 0) / contrib.total
    local skillPct = (contrib.buckets.skill or 0) / contrib.total
    local effectPct = (contrib.buckets.effect or 0) / contrib.total
    if setPct >= 0.22 then
      tips[#tips + 1] = string.format(
        "|cC0A060Build tip:|r Set procs are |cFFCC66%s|r of damage — keep set conditions up; your bars ride on that engine.",
        fmtPct(setPct)
      )
    end
    if skillPct < 0.35 and effectPct >= 0.25 then
      tips[#tips + 1] = string.format(
        "|cC0A060Build tip:|r Slotted skills are only |cFFCC66%s|r of damage; effects are |cFFCC66%s|r. Check DoTs/status uptime vs. button spam.",
        fmtPct(skillPct), fmtPct(effectPct)
      )
    end
  end

  local weave = getWeaveSuccessRatio(session)
  if totalEvents > 0 and missMiss / math.max(1, totalEvents) >= 0.25 then
    tips[#tips + 1] = "|cFF8888Focus:|r High miss rate — default pattern is |cFFFF88LA → Skill → LA → Skill|r. Consistency beats speed."
  elseif weave >= 0 and weave < 0.60 and totalEvents >= 8 then
    tips[#tips + 1] = "|cFFCC66Focus:|r Weave under 60%. Slow down casts slightly and place LA between every skill."
  end

  if #tips == 0 then
    tips[1] = "|cAAAAAANo strong patterns detected yet — run a longer dummy parse for richer insights.|r"
  end
  return tips
end

---------------------------------------------------------------------
-- Parse Diagnosis: "Where Did My DPS Go?" (estimated opportunities)
-- Estimates use this fight's observed damage — not a theory DB.
---------------------------------------------------------------------
local function loadoutFingerprint(session)
  if not session then return "" end
  local parts = {}
  if type(session.equippedSets) == "table" then
    local sets = {}
    for _, n in ipairs(session.equippedSets) do sets[#sets + 1] = string.lower(tostring(n)) end
    table.sort(sets)
    for _, n in ipairs(sets) do parts[#parts + 1] = "s:" .. n end
  end
  if type(session.slottedAbilityBySlot) == "table" then
    local ids = {}
    for _, e in pairs(session.slottedAbilityBySlot) do
      if type(e) == "table" then
        local id = tonumber(e.id) or 0
        if id > 0 then ids[#ids + 1] = id end
      end
    end
    table.sort(ids)
    for _, id in ipairs(ids) do parts[#parts + 1] = "a:" .. tostring(id) end
  end
  return table.concat(parts, "|")
end

local function lightAttackDamageStats(session)
  local dmg, hits = 0, 0
  if not session or type(session.skills) ~= "table" then return 0, 0, 0 end
  for _, sk in pairs(session.skills) do
    if type(sk) == "table" and sk.name and string.find(string.lower(sk.name), "light attack", 1, true) then
      dmg = dmg + (tonumber(sk.dmg) or 0)
      hits = hits + (tonumber(sk.hits) or 0)
    end
  end
  local avg = hits > 0 and (dmg / hits) or 0
  return dmg, hits, avg
end

local function skillCastsPerSec(session)
  local dur = tonumber(session and session.durationMs) or 0
  if dur <= 0 then return 0 end
  local w = session.weave or {}
  local presses = tonumber(w.inputSkillPresses) or tonumber(w.skillEventCount) or 0
  return presses / (dur / 1000)
end

local function bestSustainedWindowDps(session, windowSec)
  windowSec = tonumber(windowSec) or 20
  local bms = bucketMs()
  if bms <= 0 then bms = 2000 end
  local need = math.max(1, math.floor(windowSec * 1000 / bms))
  local arr = denseSparkBuckets(session)
  if #arr < need then
    return sessionAvgDps(session)
  end
  local best, run = 0, 0
  for i = 1, #arr do
    run = run + (tonumber(arr[i].dmg) or 0)
    if i > need then run = run - (tonumber(arr[i - need].dmg) or 0) end
    if i >= need and run > best then best = run end
  end
  local winSec = need * (bms / 1000)
  return winSec > 0 and (best / winSec) or 0
end

local function phaseDpsBreakdown(session)
  local arr = denseSparkBuckets(session)
  local n = #arr
  if n == 0 then
    return { opener = 0, sustained = 0, execute = 0 }
  end
  local a, b = math.max(1, math.floor(n * 0.20)), math.max(1, math.floor(n * 0.80))
  local function sumRange(i0, i1)
    local d = 0
    for i = i0, i1 do d = d + (tonumber(arr[i].dmg) or 0) end
    local sec = math.max(0.001, (i1 - i0 + 1) * (bucketMs() / 1000))
    return d / sec
  end
  return {
    opener = sumRange(1, a),
    sustained = sumRange(a + 1, b),
    execute = sumRange(b + 1, n), -- clock late phase (not health execute)
  }
end

-- Phase 3 P0: windows, DoT gaps, bar/ult summaries, exception-driven exec text
local function p3Median(nums)
  if type(nums) ~= "table" or #nums == 0 then return 0 end
  local t = {}
  for i = 1, #nums do t[i] = tonumber(nums[i]) or 0 end
  table.sort(t)
  local n = #t
  if n % 2 == 1 then return t[(n + 1) / 2] end
  return (t[n / 2] + t[n / 2 + 1]) / 2
end

local function p3Percentile(nums, p)
  if type(nums) ~= "table" or #nums == 0 then return 0 end
  local t = {}
  for i = 1, #nums do t[i] = tonumber(nums[i]) or 0 end
  table.sort(t)
  local idx = math.max(1, math.min(#t, math.ceil(#t * (p or 0.9))))
  return t[idx]
end

local function computeActiveWindows(session, windowSec)
  windowSec = tonumber(windowSec) or 20
  local bms = bucketMs()
  if bms <= 0 then bms = 2000 end
  local need = math.max(1, math.floor(windowSec * 1000 / bms))
  local arr = denseSparkBuckets(session)
  local avgDps = sessionAvgDps(session)
  local out = {
    bestActive20 = nil,
    worstActive20 = nil,
    fightAvgDps = avgDps,
  }
  if #arr < need then
    return out
  end
  -- Min activity for "active" worst: window avg dps >= 15% of fight avg (floor 5k)
  local minWinDps = math.max(5000, avgDps * 0.15)
  local bestRun, worstRun = -1, nil
  local bestI, worstI = 0, 0
  local run = 0
  for i = 1, #arr do
    run = run + (tonumber(arr[i].dmg) or 0)
    if i > need then run = run - (tonumber(arr[i - need].dmg) or 0) end
    if i >= need then
      local winSec = need * (bms / 1000)
      local dps = winSec > 0 and (run / winSec) or 0
      local startIdx = i - need + 1
      if dps > bestRun then bestRun, bestI = dps, startIdx end
      if dps >= minWinDps then
        if not worstRun or dps < worstRun then worstRun, worstI = dps, startIdx end
      end
    end
  end
  local function winFrom(startI, dpsVal)
    if not startI or startI <= 0 or not dpsVal or dpsVal < 0 then return nil end
    local startMs = (arr[startI].idx or 0) * bms
    local endMs = startMs + need * bms
    local skillDmg = {}
    for i = startI, math.min(#arr, startI + need - 1) do
      local bidx = arr[i].idx
      local b = session.buckets and session.buckets[bidx]
      if type(b) == "table" and type(b.skills) == "table" then
        for aid, d in pairs(b.skills) do
          local id = tonumber(aid) or 0
          if id > 0 then skillDmg[id] = (skillDmg[id] or 0) + (tonumber(d) or 0) end
        end
      end
    end
    local tops = {}
    for id, d in pairs(skillDmg) do tops[#tops + 1] = { id = id, dmg = d } end
    table.sort(tops, function(a, b) return a.dmg > b.dmg end)
    local skillTop = {}
    for i = 1, math.min(3, #tops) do
      local sk = session.skills and session.skills[tops[i].id]
      skillTop[i] = {
        id = tops[i].id,
        name = (sk and sk.name) or ("id " .. tostring(tops[i].id)),
        dmg = tops[i].dmg,
      }
    end
    if session.meta and session.meta.quality and #skillTop > 0 then
      session.meta.quality.bucketTopSources = true
    end
    return {
      startMs = startMs,
      endMs = endMs,
      dps = dpsVal,
      skillTop = skillTop,
      eligible = true,
    }
  end
  out.bestActive20 = winFrom(bestI, bestRun)
  out.worstActive20 = winFrom(worstI, worstRun)
  return out
end

local function computeDotQuality(session)
  local map = {}
  if not session or type(session.dotTicks) ~= "table" then return map end
  local dur = tonumber(session.durationMs) or 0
  if dur <= 0 then return map end
  for id, entry in pairs(session.dotTicks) do
    local aid = tonumber(id) or 0
    local ticks = entry and entry.ticks
    local name = (entry and entry.name) or "?"
    local tickN = tonumber(entry and entry.tickCount) or (type(ticks) == "table" and #ticks) or 0
    if isWeaponEnchantStatusDot(name) or isUltimateAbility(aid, session, name) then
      -- skip
    elseif tickN >= 3 or (type(ticks) == "table" and #ticks >= 3) then
      local med = tonumber(entry.medianIntervalMs) or 0
      local gapCount, gapMs, maxG = 0, 0, 0
      if type(ticks) == "table" and #ticks >= 2 then
        local intervals = {}
        for i = 2, #ticks do intervals[#intervals + 1] = ticks[i] - ticks[i - 1] end
        table.sort(intervals)
        if med <= 0 then med = intervals[math.ceil(#intervals / 2)] or 2000 end
        if med > 200 then
          local maxGap = math.max(med * 1.6, med + 500)
          for i = 2, #ticks do
            local g = ticks[i] - ticks[i - 1]
            if g > maxGap then
              gapCount = gapCount + 1
              gapMs = gapMs + g
              if g > maxG then maxG = g end
            end
          end
        end
      end
      if med <= 0 then med = 2000 end
      if med > 200 then
        local up = select(1, estimateDotUptimeEntry(entry, dur))
        map[aid] = {
          id = aid,
          name = name,
          uptime = up,
          gapCount = gapCount,
          gapMs = gapMs,
          maxGapMs = maxG,
          gapConf = "Calculated",
          ticks = tickN,
        }
      end
    end
  end
  return map
end

local function finalizePhase3Execution(session)
  if type(session) ~= "table" then return nil end
  session.meta = session.meta or { captureSchemaVersion = "3.0", quality = {} }
  session.meta.analysisVersion = "3.0-p0"
  session.meta.quality = session.meta.quality or {}

  -- Ult damage from skill table
  local ue = session.ultEconomy or { casts = 0, castTimes = {}, damage = 0 }
  local ultDmg = 0
  if type(session.skills) == "table" then
    for id, sk in pairs(session.skills) do
      if type(sk) == "table" then
        local aid = tonumber(sk.id) or tonumber(id) or 0
        if isUltimateAbility(aid, session, sk.name) then
          ultDmg = ultDmg + (tonumber(sk.dmg) or 0)
        end
      end
    end
  end
  ue.damage = ultDmg
  local total = tonumber(session.totalDamage) or 0
  ue.shareOfParse = total > 0 and (ultDmg / total) or 0
  if type(ue.castTimes) == "table" and #ue.castTimes >= 2 then
    local gaps = {}
    for i = 2, #ue.castTimes do gaps[#gaps + 1] = ue.castTimes[i] - ue.castTimes[i - 1] end
    ue.meanRecastGapMs = p3Median(gaps)
  end
  -- Prefer cast count from markers/casts; if 0 but damage, leave casts as-is
  session.ultEconomy = ue

  -- Bar delay distribution
  local bs = session.barStats or {}
  local delays = type(bs.swapDelayMs) == "table" and bs.swapDelayMs or {}
  bs.delayMedian = p3Median(delays)
  bs.delayP90 = p3Percentile(delays, 0.9)
  bs.delayMax = 0
  for _, d in ipairs(delays) do
    d = tonumber(d) or 0
    if d > bs.delayMax then bs.delayMax = d end
  end
  local fMs = tonumber(bs.frontMs) or 0
  local bMs = tonumber(bs.backMs) or 0
  local uMs = tonumber(bs.unknownMs) or 0
  local sumB = fMs + bMs + uMs
  if sumB <= 0 then sumB = tonumber(session.durationMs) or 1 end
  bs.frontDwell = fMs / sumB
  bs.backDwell = bMs / sumB
  bs.unknownDwell = uMs / sumB
  bs.swapCount = (type(bs.swaps) == "table" and #bs.swaps)
    or (session.weave and tonumber(session.weave.barSwapCount)) or 0
  session.barStats = bs

  -- Windows
  session.windowStats = computeActiveWindows(session, 20)

  -- DoT quality
  session.dotQuality = computeDotQuality(session)

  -- late_phase marker once
  local dur = tonumber(session.durationMs) or 0
  local markers = session.markers or { points = {} }
  markers.points = markers.points or {}
  local hasLate = false
  for _, p in ipairs(markers.points) do
    if p.type == "late_phase" then hasLate = true break end
  end
  if not hasLate and dur >= 20000 then
    local start = tonumber(session.startMs) or 0
    markers.points[#markers.points + 1] = {
      tMs = start + math.floor(dur * 0.80),
      type = "late_phase",
      label = "late",
    }
  end
  session.markers = markers

  -- Exception-driven exec summary for Insights §4
  local lines = {}
  local primary, watch, stable
  local wstat = session.windowStats or {}
  local best = wstat.bestActive20
  local worst = wstat.worstActive20
  if best and worst and best.dps > 0 and worst.dps > 0 and worst.dps < best.dps * 0.82 then
    local t0 = math.floor((worst.startMs or 0) / 1000)
    local t1 = math.floor((worst.endMs or 0) / 1000)
    primary = string.format(
      "Primary: weak active 20s (best %s → worst %s, t=%d:%02d–%d:%02d) — busiest stretch, not fight avg  [Calculated]",
      fmtDps(best.dps), fmtDps(worst.dps),
      math.floor(t0 / 60), t0 % 60, math.floor(t1 / 60), t1 % 60
    )
  end
  -- Top DoT gaps
  local worstDot, worstGaps, worstMax = nil, 0, 0
  for _, dq in pairs(session.dotQuality or {}) do
    if (tonumber(dq.gapCount) or 0) > worstGaps then
      worstGaps = dq.gapCount
      worstDot = dq.name
      worstMax = tonumber(dq.maxGapMs) or 0
    end
  end
  if worstDot and worstGaps >= 2 then
    local gapLine = string.format(
      "DoT gaps: %s ×%d (max %0.1fs)  [Calculated]",
      displayName(worstDot, 28), worstGaps, worstMax / 1000
    )
    if not primary then primary = "Primary: " .. gapLine
    else watch = "Watch: " .. gapLine end
  end
  if (tonumber(bs.delayOverThresholdCount) or 0) >= 2 then
    local swapLine = string.format(
      "Swap delays: %d over 400ms · med %0.0f · p90 %0.0f  [Observed]",
      bs.delayOverThresholdCount or 0, bs.delayMedian or 0, bs.delayP90 or 0
    )
    if not primary then primary = "Primary: " .. swapLine
    elseif not watch then watch = "Watch: " .. swapLine
    end
  end
  local weavePct = getWeaveSuccessRatio(session)
  local ultCasts = tonumber(ue.casts) or 0
  local firstUlt = tonumber(ue.firstUltMs) or 0
  stable = string.format(
    "Stable: weave %s · bars F %0.0f%%/B %0.0f%% · %d swaps · ult %d cast(s)%s  [Observed]",
    fmtPct(weavePct),
    (bs.frontDwell or 0) * 100, (bs.backDwell or 0) * 100,
    tonumber(bs.swapCount) or 0,
    ultCasts,
    ultCasts > 0 and string.format(" · first %0.0fs · %s dmg", firstUlt / 1000, fmtPct(ue.shareOfParse or 0)) or ""
  )
  if not primary then
    primary = "Execution looks stable this parse (no large active-window or DoT-gap exception)."
  end
  lines[1] = primary
  if watch then lines[#lines + 1] = watch end
  lines[#lines + 1] = stable
  if best and worst then
    lines[#lines + 1] = string.format(
      "Windows: best active %s · worst active %s  [Calculated]",
      fmtDps(best.dps), fmtDps(worst.dps)
    )
  end
  lines[#lines + 1] = "More: Rotation"
  session.execSummary = {
    lines = lines,
    primary = primary,
    watch = watch,
    stable = stable,
  }
  return session.execSummary
end
M.FinalizePhase3Execution = finalizePhase3Execution

local function ensurePhase3Summary(session)
  if not session then return nil end
  if type(session.execSummary) == "table" and session.execSummary.lines then
    return session.execSummary
  end
  return finalizePhase3Execution(session)
end

local function findPersonalBenchmarks(session)
  local curDps = sessionAvgDps(session)
  local fp = loadoutFingerprint(session)
  local best, bestS, sum, cnt = curDps, session, 0, 0
  local count = historyCount()
  for offset = 0, count - 1 do
    local s = historyAt(offset)
    if s and s.isDummy and s ~= session then
      local sameLoad = (fp ~= "" and loadoutFingerprint(s) == fp)
      local sameTarget = (session.lastTargetName and s.lastTargetName
        and string.lower(tostring(s.lastTargetName)) == string.lower(tostring(session.lastTargetName)))
      if sameLoad or sameTarget or (fp == "") then
        local d = sessionAvgDps(s)
        sum = sum + d
        cnt = cnt + 1
        if d > best then best, bestS = d, s end
      end
    end
  end
  -- Always include current in average if we found others
  if cnt > 0 then
    sum = sum + curDps
    cnt = cnt + 1
  end
  return {
    current = curDps,
    personalBest = best,
    pbSession = bestS,
    recentAvg = cnt > 0 and (sum / cnt) or curDps,
    comparableCount = cnt,
    fingerprint = fp,
  }
end

-- Build ranked estimated DPS opportunities from observed parse data.
local function buildDpsOpportunities(session)
  local opps = {}
  if not session then return opps end
  local dur = tonumber(session.durationMs) or 0
  if dur < 5000 then return opps, phaseDpsBreakdown(session), findPersonalBenchmarks(session) end
  local durSec = dur / 1000
  local total = tonumber(session.totalDamage) or 0
  local w = type(session.weave) == "table" and session.weave or {}

  -- LA stats used by missed + late weave estimates
  local _, laHits, laAvg = lightAttackDamageStats(session)

  -- 1) Missed light attacks (this fight's avg LA damage)
  local missed = tonumber(w.missedCount) or 0
  if missed >= 2 and laAvg > 0 then
    local lostDmg = missed * laAvg
    local est = lostDmg / durSec
    -- Recoverable fraction (not every miss is free)
    est = est * 0.75
    opps[#opps + 1] = {
      key = "missed_la",
      title = "Missed light attacks",
      estDps = est,
      evidence = string.format("%d missed weaves · avg LA %s this parse", missed, fmtInt(laAvg)),
      drill = "Default rhythm: LA → Skill → LA → Skill. Practice the skills you miss most.",
    }
  end

  -- 2) DoT downtime (observed tick rate × gap)
  -- Exclude ultimates and weapon-enchant/status effects (not skill-refreshed).
  if type(session.dotTicks) == "table" and type(session.skills) == "table" then
    local totalDotLost = 0
    local worstName, worstLost = nil, 0
    local names = {}
    local ultGapLost, ultWorstName = 0, nil
    for id, entry in pairs(session.dotTicks) do
      local abilityId = tonumber(id) or tonumber(entry and entry.id) or 0
      local sk = session.skills[abilityId] or session.skills[id]
      local skName = (entry and entry.name) or (sk and sk.name) or "?"
      if isWeaponEnchantStatusDot(skName) then
        -- Hemorrhaging / Poisoned / Burning etc. — not "maintain this skill"
      elseif isUltimateAbility(abilityId, session, skName) then
        -- Track separately for optional ultimate cadence note (not "DoT refresh")
        local ticks = entry and entry.ticks
        if type(ticks) == "table" and #ticks >= 2 and sk then
          local skDmg = tonumber(sk.dmg) or 0
          local covered = 0
          local med = 8000
          if #ticks >= 3 then
            local intervals = {}
            for i = 2, #ticks do intervals[#intervals + 1] = ticks[i] - ticks[i - 1] end
            table.sort(intervals)
            med = intervals[math.ceil(#intervals / 2)] or med
          end
          for i = 2, #ticks do
            local gap = ticks[i] - ticks[i - 1]
            if gap <= med * 2.5 then covered = covered + gap end
          end
          covered = covered + med
          local up = math.min(1, covered / dur)
          if up < 0.70 and skDmg > 0 then
            local lost = skDmg * ((1 - up) / math.max(0.05, up)) * 0.35
            if lost > ultGapLost then ultGapLost, ultWorstName = lost, skName end
          end
        end
      else
      local ticks = entry and entry.ticks
      if type(ticks) == "table" and #ticks >= 3 then
        local intervals = {}
        for i = 2, #ticks do intervals[#intervals + 1] = ticks[i] - ticks[i - 1] end
        table.sort(intervals)
        local med = intervals[math.ceil(#intervals / 2)] or 2000
        if med > 200 then
          local expected = math.floor(dur / med)
          local missedT = math.max(0, expected - #ticks)
          local skDmg = sk and (tonumber(sk.dmg) or 0) or 0
          local avgTick = (#ticks > 0 and skDmg > 0) and (skDmg / #ticks) or 0
          if avgTick <= 0 and skDmg > 0 then avgTick = skDmg / math.max(1, expected) end
          local lost = missedT * avgTick
          -- Also estimate pure uptime gap
          local covered = 0
          for i = 2, #ticks do
            local gap = ticks[i] - ticks[i - 1]
            if gap <= med * 2.5 then covered = covered + gap end
          end
          covered = covered + med
          local up = math.min(1, covered / dur)
          if up < 0.85 and skDmg > 0 then
            local gapDmg = skDmg * ((1 - up) / math.max(0.05, up)) -- scale as if uptime were full
            -- conservative: half of theoretical gap
            lost = math.max(lost, gapDmg * 0.45)
          end
          if lost > 0 then
            totalDotLost = totalDotLost + lost
            if lost > worstLost then worstLost, worstName = lost, skName end
            names[#names + 1] = skName
          end
        end
      end
      end -- not ultimate
    end
    if totalDotLost > 0 and worstName then
      local est = (totalDotLost / durSec) * 0.55 -- recoverable fraction
      opps[#opps + 1] = {
        key = "dot_downtime",
        title = "DoT downtime",
        estDps = est,
        evidence = string.format("Weakest: %s · reapply after expire, not early", displayName(worstName, 28)),
        drill = string.format("Keep %s (and other DoTs) active — refresh after full expire windows when stacks require it.", displayName(worstName, 28)),
      }
    end
    if ultGapLost > 0 and ultWorstName and (totalDotLost <= 0 or ultGapLost > totalDotLost * 0.5) then
      local est = (ultGapLost / durSec) * 0.45
      if est >= 200 then
        opps[#opps + 1] = {
          key = "ultimate_uptime",
          title = "Ultimate uptime / cast timing",
          estDps = est,
          evidence = string.format("%s is an ultimate — not a reapplyable DoT · fire when ultimate is ready", displayName(ultWorstName, 28)),
          drill = string.format("Cast %s when ultimate is available in the rotation — do not treat it as a ground DoT to refresh.", displayName(ultWorstName, 28)),
        }
      end
    end
  end

  -- 3) Cadence / slow skill presses vs best sustained window
  local cps = skillCastsPerSec(session)
  local bestWin = bestSustainedWindowDps(session, 20)
  local avgDps = sessionAvgDps(session)
  if bestWin > avgDps * 1.08 and avgDps > 0 then
    local gap = (bestWin - avgDps) * 0.35 -- not all gap is cadence
    if gap >= 200 then
      opps[#opps + 1] = {
        key = "cadence",
        title = "Inconsistent damage cadence",
        estDps = gap,
        evidence = string.format("Best ~20s window %s vs fight avg %s · casts/s %.2f",
          fmtDps(bestWin), fmtDps(avgDps), cps),
        drill = "Match your clean mid-parse rhythm for the full fight — fewer dead gaps between skills.",
      }
    end
  end

  -- 4) Late weaves (partial LA value lost to timing)
  local late = tonumber(w.lateCount) or 0
  if late >= 4 and laAvg > 0 then
    local est = (late * laAvg * 0.25) / durSec -- late LAs still hit but cost cadence
    if est >= 150 then
      opps[#opps + 1] = {
        key = "late_weave",
        title = "Late light attacks",
        estDps = est,
        evidence = string.format("%d late weaves — LA lands but skill cadence slips", late),
        drill = "Press LA sooner after cast end; late LAs still waste global time.",
      }
    end
  end

  -- Cast pace: seconds past the cooldown, valued at this fight's average DPS.
  -- Ceiling, not a promise — damage already ticking in the gap is still in the average.
  local pace = M.SkillCastPace(session)
  if pace.samples >= 8 and pace.medianLostMs >= 50 then
    local avgDps = sessionAvgDps(session)
    local lostSec = (tonumber(pace.totalLostMs) or 0) / 1000
    local gain = (durSec > 0) and ((lostSec * avgDps) / durSec) or 0
    if gain >= 200 then
      opps[#opps + 1] = {
        key = "cast_pace",
        title = "Tighter cast timing",
        estDps = gain,
        evidence = string.format(
          "%0.1fs recapturable · %0.3f s/cast · %s at fight DPS",
          lostSec, pace.medianLostMs / 1000, fmtDpsDelta(gain)
        ),
        drill = "Queue the next skill as the cooldown ends. It will not fire any earlier.",
      }
    end
  end

  -- 5) End-phase collapse (opener/sustained vs execute buckets)
  local phases = phaseDpsBreakdown(session)
  if phases.sustained > 0 and phases.execute > 0 and phases.execute < phases.sustained * 0.82 then
    local est = (phases.sustained - phases.execute) * 0.25 -- last ~20% of fight
    if est >= 200 then
      opps[#opps + 1] = {
        key = "execute_phase",
        title = "Execute / late-fight drop",
        estDps = est,
        evidence = string.format("Sustained %s → late phase %s", fmtDps(phases.sustained), fmtDps(phases.execute)),
        drill = "Hold the same weave standard in the last 20% — panic speed usually loses DPS.",
      }
    end
  end

  -- 6) Weak opener
  if phases.opener > 0 and phases.sustained > 0 and phases.opener < phases.sustained * 0.85 then
    local est = (phases.sustained - phases.opener) * 0.20
    if est >= 200 then
      opps[#opps + 1] = {
        key = "opener",
        title = "Slow opener",
        estDps = est,
        evidence = string.format("Opener %s vs sustained %s", fmtDps(phases.opener), fmtDps(phases.sustained)),
        drill = "Pre-buff, open with DoTs + ultimate earlier, then settle into LA→skill.",
      }
    end
  end

  -- 7) Ultimate count vs personal best (if comparable)
  local function countUlts(s)
    local n = 0
    if not s or type(s.skills) ~= "table" then return 0 end
    for id, sk in pairs(s.skills) do
      if type(sk) == "table" then
        local aid = tonumber(sk.id) or tonumber(id) or 0
        if isUltimateAbility(aid, s) then
          n = n + (tonumber(sk.hits) or 0)
          -- hits on channel ults can be high; prefer cast-ish: at least 1 if dmg
          if (tonumber(sk.dmg) or 0) > 0 and n == 0 then n = 1 end
        end
      end
    end
    -- Prefer timeline skill presses for ults when possible
    local tlN = 0
    if type(s.weave) == "table" and type(s.weave.timeline) == "table" then
      for _, item in ipairs(s.weave.timeline) do
        if item and (item.kind == "skill" or item.kind == "postchannel") then
          local aid = tonumber(item.abilityId) or 0
          if isUltimateAbility(aid, s) then tlN = tlN + 1 end
        end
      end
    end
    if tlN > 0 then return tlN end
    -- crude hits fallback: cap at reasonable
    if n > 12 then n = math.ceil(n / 8) end
    return n
  end
  local ults = countUlts(session)
  local bench = findPersonalBenchmarks(session)
  if bench.pbSession and bench.pbSession ~= session and ults >= 0 then
    local pbUlts = countUlts(bench.pbSession)
    if pbUlts >= ults + 2 then
      -- Estimate from ult skill damage share
      local ultDmg = 0
      if type(session.skills) == "table" then
        for id, sk in pairs(session.skills) do
          if type(sk) == "table" then
            local aid = tonumber(sk.id) or tonumber(id) or 0
            if isUltimateAbility(aid, session) then ultDmg = ultDmg + (tonumber(sk.dmg) or 0) end
          end
        end
      end
      local perUlt = ults > 0 and (ultDmg / ults) or (total * 0.08)
      local est = ((pbUlts - ults) * perUlt * 0.5) / durSec
      if est >= 200 then
        opps[#opps + 1] = {
          key = "ultimate",
          title = "Fewer ultimate casts than your best",
          estDps = est,
          evidence = string.format("This parse %d ults · personal best ~%d", ults, pbUlts),
          drill = "Generate ult faster (LA density, skill cost) and dump when ready outside bad windows.",
        }
      end
    end
  end

  -- Phase 3 P0: active-window collapse + maintainable DoT gaps (after ensure summary)
  ensurePhase3Summary(session)
  local wstat = session.windowStats or {}
  local bestW = wstat.bestActive20
  local worstW = wstat.worstActive20
  if bestW and worstW and (tonumber(bestW.dps) or 0) > 0
      and (tonumber(worstW.dps) or 0) < (tonumber(bestW.dps) or 0) * 0.82 then
    local est = ((tonumber(bestW.dps) or 0) - (tonumber(worstW.dps) or 0)) * 0.22
    if est >= 200 then
      local t0 = math.floor((tonumber(worstW.startMs) or 0) / 1000)
      opps[#opps + 1] = {
        key = "window_collapse",
        title = "Active-window collapse",
        estDps = est,
        evidence = string.format(
          "Best vs worst busy 20s: %s → %s @ t=%d:%02d  (not full-fight avg)  [Calculated]",
          fmtDps(bestW.dps), fmtDps(worstW.dps), math.floor(t0 / 60), t0 % 60
        ),
        drill = "Active window = busiest/weakest 20s with real damage (not idle tails). Hold cadence in weak stretches — see Rotation.",
      }
    end
  end
  local topGapName, topGapN, topGapMax, topGapEst = nil, 0, 0, 0
  for _, dq in pairs(session.dotQuality or {}) do
    local gc = tonumber(dq.gapCount) or 0
    if gc > topGapN then
      topGapN = gc
      topGapName = dq.name
      topGapMax = tonumber(dq.maxGapMs) or 0
      local skDmg = 0
      if session.skills and session.skills[dq.id] then
        skDmg = tonumber(session.skills[dq.id].dmg) or 0
      end
      topGapEst = (skDmg * 0.12 * math.min(3, gc)) / math.max(1, durSec)
    end
  end
  if topGapName and topGapN >= 2 and topGapEst >= 150 then
    opps[#opps + 1] = {
      key = "dot_gaps",
      title = "DoT long gaps",
      estDps = topGapEst,
      evidence = string.format(
        "%s · %d long gaps · max %0.1fs  [Calculated]",
        displayName(topGapName, 28), topGapN, topGapMax / 1000
      ),
      drill = string.format(
        "Reapply %s before long drops — see Weave DoT gaps and Rotation.",
        displayName(topGapName, 28)
      ),
    }
  end

  table.sort(opps, function(a, b) return (a.estDps or 0) > (b.estDps or 0) end)
  return opps, phases, bench
end

local function buildParseDiagnosis(session)
  if not session then
    return {
      headline = "Complete a parse to unlock diagnosis.",
      opportunities = {},
      tips = {},
    }
  end
  local opps, phases, bench = buildDpsOpportunities(session)
  local cur = sessionAvgDps(session)
  local deltaPb = (bench and bench.personalBest or cur) - cur
  local totalOpp = 0
  for i = 1, math.min(3, #opps) do totalOpp = totalOpp + (opps[i].estDps or 0) end

  local headline
  if bench and bench.comparableCount >= 2 and deltaPb > 500 then
    headline = string.format(
      "%s DPS  —  |cFFCC66%s below|r your comparable best (%s)",
      fmtDps(cur), fmtDps(deltaPb), fmtDps(bench.personalBest)
    )
  elseif bench and bench.comparableCount >= 2 and deltaPb < -500 then
    headline = string.format(
      "%s DPS  —  |c66FF88new comparable best|r (avg %s over %d)",
      fmtDps(cur), fmtDps(bench.recentAvg), bench.comparableCount
    )
  else
    headline = string.format(
      "%s DPS  ·  est. recoverable ~%s if top gaps close",
      fmtDps(cur), fmtDps(totalOpp)
    )
  end

  local nextDrill = "Run another dummy parse to build personal benchmarks."
  if opps[1] and opps[1].drill then
    nextDrill = opps[1].drill
  end

  local primaryBits = {}
  for i = 1, math.min(3, #opps) do
    primaryBits[#primaryBits + 1] = string.format("%s (−%s)", opps[i].title, fmtDps(opps[i].estDps))
  end

  return {
    headline = headline,
    currentDps = cur,
    bench = bench,
    phases = phases or phaseDpsBreakdown(session),
    opportunities = opps,
    totalTopOpp = totalOpp,
    primaryLine = (#primaryBits > 0)
      and ("Primary gaps: " .. table.concat(primaryBits, "  ·  "))
      or "No large recoverable gaps detected on this parse.",
    nextDrill = "Next drill: " .. nextDrill,
    tips = buildPatternInsights(session),
    disclaimer = "Estimates use this fight's observed damage — not guaranteed free DPS.",
  }
end

---------------------------------------------------------------------
-- Build Fit (v1): parse damage mix + top sources + slotted CP alignment
-- Heuristic fit scores from CP name/desc vs this parse — not A/B losses.
---------------------------------------------------------------------
local function classifyChampionCategory(name, desc)
  local t = string.lower(tostring(name or "") .. " " .. tostring(desc or ""))
  if t == " " or t == "" then return "mixed", "Mixed" end

  -- Defensive / pure utility first (dummy-parse soft fits)
  if string.find(t, "vitalit", 1, true) or string.find(t, "fortif", 1, true)
      or string.find(t, "rejuvenat", 1, true) or string.find(t, "ironclad", 1, true)
      or string.find(t, "hardy", 1, true) or string.find(t, "elemental aegis", 1, true)
      or string.find(t, "bastion", 1, true) or string.find(t, "shield", 1, true)
      or string.find(t, "block", 1, true) or string.find(t, "dodge", 1, true)
      or string.find(t, "mitigat", 1, true) or string.find(t, "incoming damage", 1, true)
      or string.find(t, "damage taken", 1, true) then
    return "utility", "Utility"
  end
  if string.find(t, "recover", 1, true) or string.find(t, "cost reduction", 1, true)
      or string.find(t, "magicka recovery", 1, true) or string.find(t, "stamina recovery", 1, true)
      or string.find(t, "sustain", 1, true) or string.find(t, "resource", 1, true) then
    return "utility", "Utility"
  end

  if string.find(t, "damage over time", 1, true) or string.find(t, "over time", 1, true)
      or string.find(t, "thaumaturge", 1, true) or string.find(t, "dot", 1, true)
      or string.find(t, "bleed", 1, true) or string.find(t, "poison", 1, true)
      or string.find(t, "disease", 1, true) or string.find(t, "burning", 1, true)
      or string.find(t, "status effect", 1, true) or string.find(t, "force of nature", 1, true) then
    return "dot", "DoT"
  end

  if string.find(t, "critical", 1, true) or string.find(t, "crit ", 1, true)
      or string.find(t, "crit$", 1, false) or string.find(t, "backstabber", 1, true)
      or string.find(t, "fighting finesse", 1, true) or string.find(t, "exploite", 1, true)
      or string.find(t, "precision", 1, true) then
    return "crit", "Crit"
  end

  if string.find(t, "ultimate", 1, true) then
    return "ult", "Ultimate"
  end

  if string.find(t, "penetrat", 1, true) or string.find(t, "resistance", 1, true)
      or string.find(t, "breach", 1, true) or string.find(t, "piercing", 1, true) then
    return "pen", "Pen"
  end

  if string.find(t, "area of effect", 1, true) or string.find(t, "aoe", 1, true)
      or string.find(t, "biting aura", 1, true) or string.find(t, "nearby enem", 1, true) then
    return "aoe", "AoE"
  end

  if string.find(t, "light attack", 1, true) or string.find(t, "weapon attack", 1, true)
      or string.find(t, "master%-at%-arms", 1, false) or string.find(t, "master at arms", 1, true)
      or string.find(t, "direct damage", 1, true) or string.find(t, "single target", 1, true)
      or string.find(t, "deadly aim", 1, true) then
    return "direct", "Direct"
  end

  if string.find(t, "weapon damage", 1, true) or string.find(t, "spell damage", 1, true)
      or string.find(t, "wrathful", 1, true) or string.find(t, "damage done", 1, true)
      or string.find(t, "increase.*damage", 1, false) then
    return "direct", "Direct"
  end

  return "mixed", "Mixed"
end

local function buildBuildSynergy(session)
  local empty = {
    mixLine = "",
    headline = "",
    topSources = {},
    cps = {},
    strongCount = 0,
    softCount = 0,
    cpTotal = 0,
    disclaimer = "Fit estimates from CP names + this parse damage mix - not A/B tested.",
  }
  if not session then return empty end

  local total = tonumber(session.totalDamage) or 0
  local direct = tonumber(session.directDamage) or 0
  local dot = tonumber(session.dotDamage) or 0
  if total <= 0 and type(session.skills) == "table" then
    for _, sk in pairs(session.skills) do
      if type(sk) == "table" then total = total + (tonumber(sk.dmg) or 0) end
    end
  end
  local directPct = total > 0 and (direct / total) or 0
  local dotPct = total > 0 and (dot / total) or 0
  -- If direct/dot fields missing, approximate from skill.dot
  if direct <= 0 and dot <= 0 and total > 0 and type(session.skills) == "table" then
    local dDot = 0
    for _, sk in pairs(session.skills) do
      if type(sk) == "table" then dDot = dDot + (tonumber(sk.dot) or 0) end
    end
    dotPct = dDot / total
    directPct = 1 - dotPct
  end
  local critPct = sessionCritPct(session)
  local contrib = buildDamageContribution(session)
  local buckets = contrib and contrib.buckets or {}
  -- Prefer contribution buckets; fall back to session.sets for set share (more reliable)
  local setFromTable = 0
  if type(session.sets) == "table" then
    for _, ps in pairs(session.sets) do
      if type(ps) == "table" then setFromTable = setFromTable + (tonumber(ps.dmg) or 0) end
    end
  end
  local setDmg = math.max(tonumber(buckets.set) or 0, setFromTable)
  local skillDmg = tonumber(buckets.skill) or 0
  local ultDmg = tonumber(buckets.ultimate) or 0
  local laDmg = tonumber(buckets.light) or 0
  local effectDmg = tonumber(buckets.effect) or 0
  -- Denominator: fight total, else sum of parts
  local mixTotal = total
  local partSum = skillDmg + setDmg + ultDmg + laDmg + effectDmg
  if mixTotal <= 0 then mixTotal = partSum end
  -- If contribution classified almost nothing but skills have damage, rebuild from top-source path
  if partSum < (mixTotal * 0.05) and type(session.skills) == "table" then
    skillDmg, setDmg, ultDmg, laDmg, effectDmg = 0, setFromTable, 0, 0, 0
    for id, sk in pairs(session.skills) do
      if type(sk) == "table" then
        local dmg = tonumber(sk.dmg) or 0
        if dmg > 0 then
          local abilityId = tonumber(sk.id) or tonumber(id) or 0
          local name = sk.name or getAbilityName(abilityId)
          local bar = getSkillBar(session, abilityId)
          local source = classifyDamageSource(session, abilityId, name, bar)
          if source == "Ultimate" then ultDmg = ultDmg + dmg
          elseif source == "Light attack" then laDmg = laDmg + dmg
          elseif source == "Set proc" then setDmg = setDmg + dmg
          elseif source == "Skill" then skillDmg = skillDmg + dmg
          else effectDmg = effectDmg + dmg end
        end
      end
    end
    setDmg = math.max(setDmg, setFromTable)
    partSum = skillDmg + setDmg + ultDmg + laDmg + effectDmg
    if mixTotal <= 0 then mixTotal = partSum end
  end
  local function mixPct(dmg) return mixTotal > 0 and (dmg / mixTotal) or 0 end
  local skillPct, setPct = mixPct(skillDmg), mixPct(setDmg)
  local ultPct, laPct, effectPct = mixPct(ultDmg), mixPct(laDmg), mixPct(effectDmg)

  local mixLine = string.format(
    "Direct %s  ·  DoT %s  ·  Crit %s  ·  Skills %s  ·  Sets %s  ·  Ult %s  ·  LA %s  ·  Fx %s",
    fmtPct(directPct), fmtPct(dotPct), fmtPct(critPct),
    fmtPct(skillPct), fmtPct(setPct), fmtPct(ultPct), fmtPct(laPct), fmtPct(effectPct)
  )

  -- Top damage sources with F/B/U/S/E chips (skills + set procs merged by dmg)
  local srcArr = {}
  if type(session.skills) == "table" then
    for id, sk in pairs(session.skills) do
      if type(sk) == "table" then
        local dmg = tonumber(sk.dmg) or 0
        if dmg > 0 then
          local abilityId = tonumber(sk.id) or tonumber(id) or 0
          local name = sk.name or getAbilityName(abilityId)
          if not name or name == "" then name = "?" end
          local bar = getSkillBar(session, abilityId)
          local source, chip = classifyDamageSource(session, abilityId, name, bar)
          local skDot = tonumber(sk.dot) or 0
          local kind = (dmg > 0 and skDot / dmg > 0.95) and "DoT"
            or (dmg > 0 and skDot / dmg < 0.05) and "Direct" or "Mixed"
          srcArr[#srcArr + 1] = {
            name = name,
            dmg = dmg,
            share = total > 0 and (dmg / total) or 0,
            chip = chip or "",
            source = source,
            kind = kind,
          }
        end
      end
    end
  end
  table.sort(srcArr, function(a, b) return (a.dmg or 0) > (b.dmg or 0) end)
  local topSources = {}
  for i = 1, math.min(INSIGHT_SYN_SRC_ROWS, #srcArr) do
    topSources[i] = srcArr[i]
  end

  -- Prefer fight-time champion snapshot (stable A/B + history view); live as fallback
  -- Insights is combat-facing: skip Craft/world stars (riding, gathering, treasure, etc.)
  local slotted = nil
  local b = session.build or session.buildEnd or session.buildStart
  if type(b) == "table" and type(b.champion) == "table" and #b.champion > 0 then
    slotted = b.champion
  else
    slotted = collectSlottedChampionSkills(12)
  end
  local cps = {}
  local strongCount, softCount = 0, 0
  local fitnessCount, warfareCount = 0, 0
  local isDummy = session.isDummy == true

  for _, cp in ipairs(slotted or {}) do
    local constellation = cp.constellation or "unknown"
    -- Craft tree stars are not combat-facing on Insights
    if constellation ~= "craft" then
      -- Fitness: dummy does not hit back. Do not Strong/Soft-rate survivability
      -- stars against this parse's damage mix (Boundless, Fortified, HP-on-hit, etc.).
      if constellation == "fitness" then
        fitnessCount = fitnessCount + 1
        local fitLabel, fitKey, reason, impact
        if isDummy then
          fitLabel, fitKey = "N/A", "na"
          reason = "Fitness · dummy does not test incoming damage"
          impact = "survivability / sustain — dummy does not hit back"
        else
          fitLabel, fitKey = "Surv", "surv"
          reason = "Fitness · survivability (not DPS-scored)"
          impact = "HP / mitigation / resource on being hit — not measured as DPS"
        end
        cps[#cps + 1] = {
          name = cp.name or "?",
          id = cp.id,
          cat = "survivability",
          catLabel = "Fitness",
          score = -1,
          fitLabel = fitLabel,
          fitKey = fitKey,
          reason = reason,
          impact = impact,
          constellation = constellation,
          rankTxt = "—",
        }
      else
      local cat, catLabel = classifyChampionCategory(cp.name, cp.desc)
      -- Extra name filter if constellation API missed a world star
      local nlow = string.lower(tostring(cp.name or "") .. " " .. tostring(cp.desc or ""))
      local isWorldUtil = string.find(nlow, "rider", 1, true)
        or string.find(nlow, "gather", 1, true)
        or string.find(nlow, "treasure", 1, true)
        or string.find(nlow, "merchant", 1, true)
        or string.find(nlow, "inspiration", 1, true)
        or string.find(nlow, "liquid efficiency", 1, true)
        or string.find(nlow, "steed", 1, true)
        or string.find(nlow, "out of sight", 1, true)
        or string.find(nlow, "fleet", 1, true)
        or string.find(nlow, "breakfall", 1, true)
        or string.find(nlow, "soul reservoir", 1, true)
        or string.find(nlow, "rationer", 1, true)
        or string.find(nlow, "homemaker", 1, true)
        or string.find(nlow, "professional upkeep", 1, true)
        or string.find(nlow, "gifted rider", 1, true)
        or string.find(nlow, "master gatherer", 1, true)
        or string.find(nlow, "plentiful harvest", 1, true)
        or string.find(nlow, "wanderer", 1, true)
        or string.find(nlow, "angler", 1, true)
        or string.find(nlow, "cutpurse", 1, true)

      if not isWorldUtil then
        local score = 45 -- baseline mixed
        local reason = "general damage star"
        local impact = "mixed combat"

        if cat == "dot" then
          score = 20 + dotPct * 100
          reason = string.format("DoT · parse DoT %s", fmtPct(dotPct))
          impact = string.format("aligns with DoT %s of dmg", fmtPct(dotPct))
          if dotPct >= 0.50 then score = score + 10; impact = "strong DoT parse match" end
          if dotPct < 0.25 then score = score - 12; impact = "DoT star · parse is direct-heavy" end
        elseif cat == "direct" then
          score = 20 + directPct * 100
          reason = string.format("Direct · parse direct %s", fmtPct(directPct))
          impact = string.format("aligns with direct %s of dmg", fmtPct(directPct))
          if directPct >= 0.55 then score = score + 10; impact = "strong direct parse match" end
          if directPct < 0.30 then score = score - 10; impact = "direct star · parse is DoT-heavy" end
        elseif cat == "crit" then
          score = 25 + critPct * 85
          reason = string.format("Crit · parse crit %s", fmtPct(critPct))
          impact = string.format("crit rate this parse %s", fmtPct(critPct))
          if critPct >= 0.58 then score = score + 8; impact = "high crit parse · star pays" end
          if critPct < 0.42 then score = score - 8; impact = "crit star · low crit this parse" end
        elseif cat == "ult" then
          score = 18 + ultPct * 140
          if ultPct < 0.04 then
            reason = "Ult · low ult damage this parse"
            impact = "ult share low · soft on this parse"
          else
            reason = string.format("Ult · ult share %s", fmtPct(ultPct))
            impact = string.format("ult %s of dmg this parse", fmtPct(ultPct))
          end
        elseif cat == "pen" then
          score = 55
          reason = "Penetration star"
          impact = "pen always relevant on dummy; trial may @cap"
          if setPct >= 0.15 then score = score + 4 end
        elseif cat == "aoe" then
          score = isDummy and 30 or 52
          reason = isDummy and "AoE · dummy is single-target" or "AoE star"
          impact = isDummy and "little ST parse impact" or "helps multi-target"
        elseif cat == "utility" then
          score = isDummy and 20 or 40
          reason = isDummy and "Utility · soft on pure dummy DPS" or "Utility"
          impact = isDummy and "not parse-visible" or "less visible on dummy"
        else
          score = 40 + skillPct * 30 + setPct * 20
          reason = "Mixed / general combat"
          impact = string.format("skills %s · sets %s", fmtPct(skillPct), fmtPct(setPct))
        end

        -- Bonus when category matches dominant damage shape / set share
        if cat == "dot" and dotPct >= 0.45 then score = score + 8 end
        if cat == "direct" and directPct >= 0.55 then score = score + 8 end
        if cat == "crit" and critPct >= 0.55 then score = score + 6 end
        if setPct >= 0.12 and (cat == "direct" or cat == "crit") then
          score = score + 4
          if cat == "direct" then impact = impact .. " · set-heavy" end
        end
        if laPct >= 0.12 and cat == "direct" then
          score = score + 3
        end

        if score > 100 then score = 100 end
        if score < 0 then score = 0 end

        local fitLabel, fitKey
        if score >= 62 then
          fitLabel, fitKey = "Strong", "strong"
          strongCount = strongCount + 1
        elseif score >= 42 then
          fitLabel, fitKey = "OK", "ok"
        else
          fitLabel, fitKey = "Soft", "soft"
          softCount = softCount + 1
        end

        cps[#cps + 1] = {
          name = cp.name or "?",
          id = cp.id,
          cat = cat,
          catLabel = catLabel,
          score = score,
          fitLabel = fitLabel,
          fitKey = fitKey,
          reason = reason,
          impact = impact,
          constellation = constellation,
        }
        warfareCount = warfareCount + 1
      end -- not world util
      end -- not fitness
    end -- not craft constellation
  end

  table.sort(cps, function(a, b)
    local af = (a.constellation == "fitness") and 1 or 0
    local bf = (b.constellation == "fitness") and 1 or 0
    if af ~= bf then return af < bf end
    if (a.score or 0) ~= (b.score or 0) then return (a.score or 0) > (b.score or 0) end
    return tostring(a.name or "") < tostring(b.name or "")
  end)
  local warfareRank = 0
  for _, c in ipairs(cps) do
    if c.constellation == "fitness" then
      c.rankTxt = "—"
    else
      warfareRank = warfareRank + 1
      c.rankTxt = tostring(warfareRank)
    end
  end

  local headline
  if #cps == 0 then
    headline = "Top damage sources ranked · no champion bar stars read (check CP slots / reload)"
  else
    local fitnessBit = ""
    if fitnessCount > 0 then
      if isDummy then
        fitnessBit = string.format("  ·  %d Fitness not dummy-rated", fitnessCount)
      else
        fitnessBit = string.format("  ·  %d Fitness (survivability, not DPS-scored)", fitnessCount)
      end
    end
    headline = string.format(
      "%d Strong · %d Soft of %d Warfare%s",
      strongCount, softCount, warfareCount, fitnessBit
    )
  end

  -- Eligible damage % by category (Phase 2 — not marginal DPS)
  local totalDmg = mixTotal > 0 and mixTotal or total
  local directDmg = totalDmg * directPct
  local dotDmg = totalDmg * dotPct
  for _, c in ipairs(cps) do
    local elig, eligNote = 0, ""
    local cat = c.cat or "mixed"
    if cat == "survivability" or c.constellation == "fitness" then
      c.eligibleDmg = 0
      c.eligiblePct = 0
      c.eligibleNote = isDummy and "not dummy-measurable" or "survivability (not DPS)"
      c.eligibleConf = CONFIDENCE.INSUFFICIENT
      c.marginalConf = CONFIDENCE.INSUFFICIENT
      c.marginalNote = "Fitness stars are not scored as dummy DPS"
      -- keep the survivability impact line set above
    elseif cat == "dot" then
      elig, eligNote = dotDmg, "DoT damage"
    elseif cat == "direct" then
      elig, eligNote = directDmg, "direct damage"
    elseif cat == "crit" then
      elig, eligNote = totalDmg * critPct, "crit-rate share of total (approx)"
    elseif cat == "ult" then
      elig, eligNote = ultDmg, "ultimate damage"
    elseif cat == "pen" then
      elig, eligNote = totalDmg, "all damage (pen)"
    elseif cat == "aoe" then
      if isDummy then
        elig = totalDmg * 0.15
        eligNote = "limited on single-target dummy"
      else
        elig = totalDmg * 0.55
        eligNote = "multi-target proxy"
      end
    else
      elig = totalDmg * (0.35 + skillPct * 0.4)
      eligNote = "mixed combat proxy"
    end
    if cat ~= "survivability" and c.constellation ~= "fitness" then
      c.eligibleDmg = elig
      c.eligiblePct = totalDmg > 0 and (elig / totalDmg) or 0
      c.eligibleNote = eligNote
      c.eligibleConf = CONFIDENCE.ESTIMATED
      c.marginalConf = CONFIDENCE.INSUFFICIENT
      c.marginalNote = "Marginal DPS needs other damage-done bonuses — not claimed"
      c.impact = string.format(
        "Eligible %s (%s) · %s",
        fmtPct(c.eligiblePct),
        eligNote,
        c.impact or c.reason or ""
      )
    end
  end

  return {
    mixLine = mixLine,
    headline = headline,
    topSources = topSources,
    cps = cps,
    strongCount = strongCount,
    softCount = softCount,
    cpTotal = #cps,
    directPct = directPct,
    dotPct = dotPct,
    critPct = critPct,
    directDmg = directDmg,
    dotDmg = dotDmg,
    ultDmg = ultDmg,
    setDmg = setDmg,
    totalDmg = totalDmg,
    disclaimer = "Eligible % matches damage categories — not free DPS. Marginal contribution: Insufficient Data until multipliers known.",
  }
end

-- ESO common reduction amounts (Major Breach / Crusher gold approx)
local MAJOR_BREACH_PEN = 5948
local MINOR_BREACH_PEN = 2974
local CRUSHER_PEN_GOLD = 2108

local function buffUptimeByNameKey(session, keySubstr)
  if not session or type(session.buffs) ~= "table" then return 0, nil end
  local dur = tonumber(session.durationMs) or 0
  if dur <= 0 then return 0, nil end
  local best, bestName = 0, nil
  local key = string.lower(tostring(keySubstr or ""))
  for _, b in pairs(session.buffs) do
    if type(b) == "table" and b.name then
      local low = string.lower(tostring(b.name))
      if string.find(low, key, 1, true) then
        local up = (tonumber(b.activeMs) or 0) / dur
        if up > best then best, bestName = up, b.name end
      end
    end
  end
  return best, bestName
end

local function debuffUptimeByNameKey(session, keySubstr)
  if not session or type(session.targetDebuffs) ~= "table" then return 0, nil end
  local dur = tonumber(session.durationMs) or 0
  if dur <= 0 then return 0, nil end
  local best, bestName = 0, nil
  local key = string.lower(tostring(keySubstr or ""))
  for _, d in pairs(session.targetDebuffs) do
    if type(d) == "table" and d.name then
      local low = string.lower(tostring(d.name))
      if string.find(low, key, 1, true) then
        local up = math.min(1, (tonumber(d.activeMs) or 0) / dur)
        if up > best then best, bestName = up, d.name end
      end
    end
  end
  return best, bestName
end

local function sheetCritDmgPercent(snap)
  if not snap or type(snap.buffed) ~= "table" then return 0 end
  local v = tonumber(snap.buffed.critDamage) or 0
  if v <= 0 then return 0 end
  if v <= 2 then return v * 100 end
  if v <= 100 then return v end
  return v
end

-- Live sheet crit-damage % for combat sampling (Phase 2.5 scaffold)
local function readSheetCritDamagePercent()
  local applyBonus = (type(STAT_BONUS_OPTION_APPLY_ALL) == "number") and STAT_BONUS_OPTION_APPLY_ALL or nil
  local softOn = (type(STAT_SOFT_CAP_OPTION_APPLY_SOFT_CAP) == "number") and STAT_SOFT_CAP_OPTION_APPLY_SOFT_CAP or nil
  local const = _G.STAT_CRITICAL_DAMAGE or _G.STAT_CRITICAL_STRIKE_DAMAGE
  if type(const) ~= "number" or type(GetPlayerStat) ~= "function" then return 0 end
  local ok, v
  if applyBonus and softOn then
    ok, v = pcall(GetPlayerStat, const, applyBonus, softOn)
  elseif applyBonus then
    ok, v = pcall(GetPlayerStat, const, applyBonus)
  else
    ok, v = pcall(GetPlayerStat, const)
  end
  v = ok and tonumber(v) or 0
  if v <= 0 then return 0 end
  if v <= 2 then return v * 100 end
  if v <= 100 then return v end
  return v
end
M.ReadSheetCritDamagePercent = readSheetCritDamagePercent

-- Finalize critDmgStats into exposure fields (uses profile ceiling on sampleSeries)
-- Path A (per-hit event crit mult) is not available on console combat events — sheet/bucket only.
local function finalizeCritDmgExposure(session, profile)
  profile = profile or getActiveContentProfile()
  local cds = session and session.critDmgStats
  if type(cds) ~= "table" then return nil end
  local ceiling = (tonumber(profile.critDamageCeiling) or 1.25) * 100
  local series = cds.sampleSeries
  local weight, sumPctDmg, atCapW, overW = 0, 0, 0, 0
  if type(series) == "table" and #series > 0 then
    for _, e in ipairs(series) do
      local d = tonumber(e.dmg) or 0
      local p = tonumber(e.pct) or 0
      if d > 0 and p > 0 then
        weight = weight + d
        sumPctDmg = sumPctDmg + (d * p)
        if p >= ceiling then
          atCapW = atCapW + d
          overW = overW + ((p - ceiling) * d / 100)
        end
      end
    end
  else
    weight = tonumber(cds.sampleWeight) or 0
    sumPctDmg = tonumber(cds.sampleCritDmgSum) or 0
    local avg0 = weight > 0 and (sumPctDmg / weight) or 0
    if avg0 >= ceiling and weight > 0 then
      atCapW = weight
      overW = ((avg0 - ceiling) * weight / 100)
    end
  end
  local elig = tonumber(cds.eligibleDmg) or 0
  if elig <= 0 then elig = weight end
  cds.atCapWeight = atCapW
  cds.overcapWeighted = overW
  cds.sampleWeight = weight
  cds.sampleCritDmgSum = sumPctDmg

  if weight <= 0 or (tonumber(cds.samples) or 0) <= 0 then
    return {
      source = cds.source or "none",
      confidence = CONFIDENCE.INSUFFICIENT,
      ceilingPct = ceiling,
      avgSheetCritPct = 0,
      capUptime = 0,
      overcapExposure = 0,
      samples = 0,
      note = "No sheet crit-damage samples (API 0 mid-combat) · per-hit crit mult not exposed on this client",
    }
  end
  local avg = sumPctDmg / weight
  local capUptime = (weight > 0) and (atCapW / weight) or 0
  -- overcapExposure = damage-weighted excess points above ceiling / eligible
  local overExp = elig > 0 and (overW / elig) or 0
  local conf = CONFIDENCE.ESTIMATED
  local note
  if cds.source == "sheet_end" then
    note = "End-of-fight sheet only · rough exposure (no mid-fight samples)"
  elseif (tonumber(cds.samples) or 0) >= 4 and weight >= (elig * 0.35) then
    note = "Damage-weighted mid-fight sheet samples · Estimated (not per-hit crit mult)"
  else
    note = "Sparse sheet samples · Estimated · not per-hit crit multiplier"
  end
  if overExp < 0.001 and capUptime < 0.05 and avg + 0.5 < ceiling then
    note = note .. " · under ceiling on sampled damage"
  end
  return {
    source = cds.source or "sheet_sample",
    confidence = conf,
    ceilingPct = ceiling,
    avgSheetCritPct = avg,
    capUptime = capUptime,
    overcapExposure = overExp,
    samples = cds.samples,
    sampleWeight = weight,
    eligibleDmg = elig,
    note = note,
  }
end
M.FinalizeCritDmgExposure = finalizeCritDmgExposure

---------------------------------------------------------------------
-- Phase 2.5.2b: CP A/B compare (core build equal, champion list differs)
---------------------------------------------------------------------
local function championIdSet(session)
  local set = {}
  local list = session and session.build and session.build.champion
  if type(list) ~= "table" and session and session.buildEnd then
    list = session.buildEnd.champion
  end
  if type(list) ~= "table" then return set, 0 end
  local n = 0
  for _, cp in ipairs(list) do
    local id = tonumber(cp.id) or 0
    if id > 0 then set[id] = true; n = n + 1 end
  end
  return set, n
end

local function championDiff(sessionA, sessionB)
  local a, na = championIdSet(sessionA)
  local b, nb = championIdSet(sessionB)
  local onlyA, onlyB = {}, {}
  for id in pairs(a) do if not b[id] then onlyA[#onlyA + 1] = id end end
  for id in pairs(b) do if not a[id] then onlyB[#onlyB + 1] = id end end
  table.sort(onlyA)
  table.sort(onlyB)
  return onlyA, onlyB, na, nb
end

-- Bars + sets + mundus from stored build snapshot (excludes champion ids)
local function coreBuildKey(session)
  if not session then return "" end
  -- Prefer precomputed stable key from capture
  local b = session.build or session.buildEnd or session.buildStart
  if type(b) == "table" and type(b.coreKey) == "string" and b.coreKey ~= "" then
    return b.coreKey
  end
  if type(session.coreBuildKey) == "string" and session.coreBuildKey ~= "" then
    return session.coreBuildKey
  end
  if type(b) ~= "table" then
    return tostring(session.buildFingerprint or "")
  end
  local function barIds(side)
    return table.concat(barSlotIdsFromBuild(b, side), ",")
  end
  local sets = {}
  if type(b.sets) == "table" then
    for _, n in ipairs(b.sets) do
      local s
      if type(n) == "table" then
        s = string.lower(tostring(n.name or ""))
      else
        s = string.lower(tostring(n or ""))
      end
      if s ~= "" then sets[#sets + 1] = s end
    end
  end
  table.sort(sets)
  local mundus = string.lower(tostring(b.mundus or session.mundus or ""))
  return table.concat({
    "F:" .. barIds("front"),
    "B:" .. barIds("back"),
    "S:" .. table.concat(sets, ","),
    "M:" .. mundus,
  }, "|")
end

local function championSkillName(id)
  id = tonumber(id) or 0
  if id <= 0 then return "?" end
  if type(GetChampionSkillName) == "function" then
    local ok, n = pcall(GetChampionSkillName, id)
    if ok and type(n) == "string" and n ~= "" then
      return (type(zo_strformat) == "function") and zo_strformat("<<1>>", n) or n
    end
  end
  return "CP " .. tostring(id)
end

-- Path B: dummy parses, duration band, same core build (bars/sets/Mundus),
-- champion list differs by exactly one star (1:1 swap or add/remove one).
local function findCpAbPairs(maxPairs)
  maxPairs = tonumber(maxPairs) or 12
  local out = {}
  local count = historyCount()
  for i = 0, count - 1 do
    local a = historyAt(i)
    if a and a.isDummy and type(a.build) == "table" then
      local keyA = coreBuildKey(a)
      if keyA ~= "" then
        for j = i + 1, count - 1 do
          local b = historyAt(j)
          if b and b.isDummy and type(b.build) == "table" then
            local durA = tonumber(a.durationMs) or 0
            local durB = tonumber(b.durationMs) or 0
            if durA >= 30000 and durB >= 30000 then
              local ratio = durA / durB
              if ratio >= 0.85 and ratio <= 1.15 then
                local keyB = coreBuildKey(b)
                if keyB == keyA then
                  local onlyA, onlyB = championDiff(a, b)
                  local nA, nB = #onlyA, #onlyB
                  -- Strict: one-star change only (1↔1 swap, or single add/remove)
                  local cleanSwap = (nA == 1 and nB == 1)
                  local singleSide = (nA == 1 and nB == 0) or (nA == 0 and nB == 1)
                  if cleanSwap or singleSide then
                    local dpsA, dpsB = sessionAvgDps(a), sessionAvgDps(b)
                    local namesA, namesB = {}, {}
                    for _, id in ipairs(onlyA) do namesA[#namesA + 1] = championSkillName(id) end
                    for _, id in ipairs(onlyB) do namesB[#namesB + 1] = championSkillName(id) end
                    local swapLabel
                    if cleanSwap then
                      swapLabel = string.format("%s ↔ %s", namesA[1], namesB[1])
                    elseif nA == 1 then
                      swapLabel = namesA[1] .. " only in A"
                    else
                      swapLabel = namesB[1] .. " only in B"
                    end
                    -- Never store sessionA/sessionB — those are SV.history tables;
                    -- embedding them under coach caused n² SV serialization bloat.
                    out[#out + 1] = {
                      offsetA = i,
                      offsetB = j,
                      onlyInA = onlyA,
                      onlyInB = onlyB,
                      namesA = namesA,
                      namesB = namesB,
                      swapLabel = swapLabel,
                      coreKey = keyA,
                      dpsA = dpsA,
                      dpsB = dpsB,
                      deltaDps = dpsA - dpsB,
                      weaveA = getWeaveSuccessRatio(a),
                      weaveB = getWeaveSuccessRatio(b),
                      cleanSwap = cleanSwap,
                      confidence = CONFIDENCE.ESTIMATED,
                      note = "Same bars/sets/Mundus · one champion star differs",
                    }
                    if #out >= maxPairs then return out end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
  return out
end
M.FindCpAbPairs = findCpAbPairs

local function medianOf(nums)
  if type(nums) ~= "table" or #nums == 0 then return 0 end
  local t = {}
  for i = 1, #nums do t[i] = nums[i] end
  table.sort(t)
  local n = #t
  if n % 2 == 1 then return t[(n + 1) / 2] end
  return (t[n / 2] + t[n / 2 + 1]) / 2
end

-- Attach Path B marginal ΔDPS onto syn.cps (median across clean pairs; Observed when n≥3)
local function applyCpAbMarginals(syn, abPairs)
  if type(syn) ~= "table" or type(syn.cps) ~= "table" then return end
  abPairs = abPairs or {}
  local deltasById = {} -- id -> { deltas={}, pair=best, swapLabel }
  for _, p in ipairs(abPairs) do
    local onlyA, onlyB = p.onlyInA or {}, p.onlyInB or {}
    local dA, dB = tonumber(p.dpsA) or 0, tonumber(p.dpsB) or 0
    -- Having the star in A vs not (or vs other): signed for each side
    if #onlyA == 1 and #onlyB == 1 then
      local idA, idB = onlyA[1], onlyB[1]
      deltasById[idA] = deltasById[idA] or { deltas = {}, pairs = {} }
      deltasById[idA].deltas[#deltasById[idA].deltas + 1] = dA - dB
      deltasById[idA].pairs[#deltasById[idA].pairs + 1] = p
      deltasById[idA].swapLabel = p.swapLabel
      deltasById[idB] = deltasById[idB] or { deltas = {}, pairs = {} }
      deltasById[idB].deltas[#deltasById[idB].deltas + 1] = dB - dA
      deltasById[idB].pairs[#deltasById[idB].pairs + 1] = p
      deltasById[idB].swapLabel = p.swapLabel
    elseif #onlyA == 1 and #onlyB == 0 then
      local idA = onlyA[1]
      deltasById[idA] = deltasById[idA] or { deltas = {}, pairs = {} }
      deltasById[idA].deltas[#deltasById[idA].deltas + 1] = dA - dB
      deltasById[idA].pairs[#deltasById[idA].pairs + 1] = p
      deltasById[idA].swapLabel = p.swapLabel
    elseif #onlyB == 1 and #onlyA == 0 then
      local idB = onlyB[1]
      deltasById[idB] = deltasById[idB] or { deltas = {}, pairs = {} }
      deltasById[idB].deltas[#deltasById[idB].deltas + 1] = dB - dA
      deltasById[idB].pairs[#deltasById[idB].pairs + 1] = p
      deltasById[idB].swapLabel = p.swapLabel
    end
  end
  for _, c in ipairs(syn.cps) do
    local id = tonumber(c.id) or 0
    local hit = deltasById[id]
    if hit and #hit.deltas > 0 then
      local med = medianOf(hit.deltas)
      local n = #hit.deltas
      local conf = (n >= 3) and CONFIDENCE.OBSERVED or CONFIDENCE.ESTIMATED
      local p = hit.pairs[1]
      c.marginalDps = med
      c.marginalConf = conf
      c.marginalN = n
      c.marginalNote = string.format(
        "A/B %s · median ΔDPS %s (n=%d)",
        hit.swapLabel or "CP swap",
        fmtDpsDelta(med),
        n
      )
      c.impact = string.format(
        "Eligible %s · A/B ΔDPS %s %s",
        fmtPct(c.eligiblePct or 0),
        fmtDpsDelta(med),
        confidenceChip(conf)
      )
      -- Scalar summary only (no session table refs)
      c.abPair = {
        swapLabel = p.swapLabel,
        deltaDps = p.deltaDps,
        dpsA = p.dpsA,
        dpsB = p.dpsB,
        offsetA = p.offsetA,
        offsetB = p.offsetB,
        confidence = conf,
      }
    end
  end
end
M.ApplyCpAbMarginals = applyCpAbMarginals

local function getActiveExperiment()
  local sv = R and R.SV
  if type(sv) ~= "table" then return nil end
  if type(sv.experiments) ~= "table" then return nil end
  return sv.experiments.active
end

local function setActiveExperiment(exp)
  -- Prefer R.SV (wired to ZO_SavedVars in main Initialize). Never invent a non-persisted table.
  local sv = R and R.SV
  if type(sv) ~= "table" then return end
  if type(sv.experiments) ~= "table" then sv.experiments = { active = nil } end
  sv.experiments.active = exp
end

-- Clear completed / abandoned experiment
local function clearActiveExperiment()
  local sv = R and R.SV
  if type(sv) ~= "table" then return end
  if type(sv.experiments) ~= "table" then sv.experiments = { active = nil } end
  sv.experiments.active = nil
end
M.ClearActiveExperiment = clearActiveExperiment

-- Map Next Test rule → experiment hold mode
-- "core" = bars/sets/Mundus fixed (CP / pen jewelry swap allowed)
-- "fingerprint" = full build id fixed (execution holds)
local function experimentChangeMeta(ruleId)
  ruleId = tostring(ruleId or "")
  if ruleId == "soft_cp" or ruleId == "crit_overcap_risk" then
    return "cp", "core", "Change only the Champion star under test"
  elseif ruleId == "pen_waste" then
    return "pen", "core", "Change only pen-related jewelry/set line; keep bars"
  elseif ruleId == "execution_opp" or ruleId == "hold_build" then
    return "execution", "fingerprint", "Keep the full build fingerprint fixed"
  end
  return "general", "fingerprint", "Keep bars/sets/Mundus/CP fixed where possible"
end

-- Start controlled experiment from Next Test (Phase 2.5.3)
local function startExperimentFromNextTest(session, nextTest, profile)
  if not session or type(nextTest) ~= "table" then return nil end
  local ruleId = nextTest.ruleId or "unknown"
  if ruleId == "sample_size" or ruleId == "experiment_active" then return nil end
  local fp = session.buildFingerprint or (session.build and session.build.fingerprint)
  local changeType, holdMode, holdHint = experimentChangeMeta(ruleId)
  local exp = {
    id = string.format("exp_%s_%s_%d", tostring(fp or "nofp"), tostring(ruleId),
      (type(os) == "table" and os.time and os.time()) or 0),
    ruleId = ruleId,
    title = nextTest.title or "Next Test",
    body = nextTest.body or "",
    baselineFingerprint = fp,
    holdCoreKey = coreBuildKey(session),
    changeType = changeType,
    holdMode = holdMode,
    holdHint = holdHint,
    changeDetail = ruleId,
    targetRuns = 3,
    runs = {},
    completed = false,
    profileId = profile and profile.id or nil,
    createdAt = (type(os) == "table" and os.time and os.time()) or 0,
  }
  setActiveExperiment(exp)
  return exp
end
M.StartExperimentFromNextTest = startExperimentFromNextTest
M.GetActiveExperiment = getActiveExperiment

-- Attach run to active experiment when hold constraints match
-- Fingerprint can drift from noisy CP/bar re-reads; if core (bars/sets/Mundus)
-- still matches, count the run so execution experiments are not stuck at 2/3.
local function tryAttachExperimentRun(session)
  local exp = getActiveExperiment()
  if not exp or type(session) ~= "table" then return end
  if exp.completed then return end
  local fp = session.buildFingerprint or (session.build and session.build.fingerprint)
  local core = coreBuildKey(session)
  if core ~= "" then session.coreBuildKey = core end
  local holdMode = exp.holdMode or "fingerprint"
  local attachNote = nil
  if holdMode == "core" then
    if exp.holdCoreKey and core ~= "" and core ~= exp.holdCoreKey then
      session.experimentWarn = "Core build changed (bars/sets/Mundus) — not counted toward experiment"
      return
    end
  else
    if exp.baselineFingerprint and fp and fp ~= exp.baselineFingerprint then
      if exp.holdCoreKey and core ~= "" and core == exp.holdCoreKey then
        -- Same bars/sets/Mundus; fingerprint hash noise only — still count
        attachNote = "core"
        session.experimentWarn = "Build ID drifted but bars/sets/Mundus hold — counted"
      else
        session.experimentWarn = "Build fingerprint changed — not counted toward active experiment"
        return
      end
    end
  end
  -- Dedup: same completedAt already recorded
  exp.runs = exp.runs or {}
  local doneAt = session.completedAt
  if doneAt then
    for _, run in ipairs(exp.runs) do
      if run.completedAt and run.completedAt == doneAt then
        session.experimentRun = { experimentId = exp.id, runIndex = run.runIndex or 0 }
        return
      end
    end
  end
  local runIndex = #exp.runs + 1
  exp.runs[runIndex] = {
    fingerprint = fp,
    coreKey = core,
    dps = sessionAvgDps(session),
    weave = getWeaveSuccessRatio(session),
    completedAt = doneAt,
    durationMs = session.durationMs,
    runIndex = runIndex,
    attachNote = attachNote,
  }
  session.experimentRun = { experimentId = exp.id, runIndex = runIndex }
  if runIndex >= (tonumber(exp.targetRuns) or 3) then
    exp.completed = true
  end
  setActiveExperiment(exp)
end
M.TryAttachExperimentRun = tryAttachExperimentRun

-- Crit *damage multiplier* is not on combat events (console). Sheet STAT_CRITICAL_DAMAGE
-- is often 0. Recipe from observed Force/Brittle uptime + known CP/racial is still useful.
local function championListHasName(session, needle)
  needle = string.lower(tostring(needle or ""))
  if needle == "" then return false end
  local list = session and ((session.build and session.build.champion)
    or (session.buildEnd and session.buildEnd.champion)
    or (session.buildStart and session.buildStart.champion))
  if type(list) ~= "table" then return false end
  for _, cp in ipairs(list) do
    local n = string.lower(tostring((type(cp) == "table" and cp.name) or ""))
    if n ~= "" and string.find(n, needle, 1, true) then return true end
  end
  return false
end

local function estimateCritDamageRecipe(session, profile)
  profile = profile or getActiveContentProfile()
  local pct = 50
  local bits = { "base 50" }
  local majF = 0
  local minF = 0
  if session then
    majF = select(1, buffUptimeByNameKey(session, "major force")) or 0
    minF = select(1, buffUptimeByNameKey(session, "minor force")) or 0
  end
  if majF >= 0.05 then
    local add = 20 * math.min(1, majF)
    pct = pct + add
    bits[#bits + 1] = string.format("Maj Force +%0.0f", add)
  elseif profile and profile.assumeMajorForce then
    pct = pct + 20
    bits[#bits + 1] = "Maj Force +20 (assumed)"
  end
  if minF >= 0.05 then
    local add = 10 * math.min(1, minF)
    pct = pct + add
    bits[#bits + 1] = string.format("Min Force +%0.0f", add)
  end
  local majB = 0
  local minB = 0
  if session then
    majB = select(1, debuffUptimeByNameKey(session, "major brittle")) or 0
    minB = select(1, debuffUptimeByNameKey(session, "minor brittle")) or 0
  end
  if majB >= 0.05 then
    local add = 20 * math.min(1, majB)
    pct = pct + add
    bits[#bits + 1] = string.format("Maj Brittle +%0.0f", add)
  end
  if minB >= 0.05 then
    local add = 10 * math.min(1, minB)
    pct = pct + add
    bits[#bits + 1] = string.format("Min Brittle +%0.0f", add)
  end
  if championListHasName(session, "fighting finesse") then
    pct = pct + 8
    bits[#bits + 1] = "Finesse +8"
  end
  if type(GetUnitRace) == "function" then
    local ok, race = pcall(GetUnitRace, "player")
    if ok and type(race) == "string" and string.find(string.lower(race), "khajiit", 1, true) then
      pct = pct + 12
      bits[#bits + 1] = "Khajiit +12"
    end
  end
  local ceiling = (tonumber(profile and profile.critDamageCeiling) or 1.25) * 100
  local over = math.max(0, pct - ceiling)
  return {
    pct = pct,
    ceiling = ceiling,
    over = over,
    bits = bits,
    recipeTxt = table.concat(bits, " + "),
  }
end

-- Phase 2 coach analysis: waste, sets, next test inputs
local function buildCoachAnalysis(session, syn, diag, profile)
  profile = profile or getActiveContentProfile()
  syn = syn or (session and buildBuildSynergy(session)) or {}
  diag = diag or (session and buildParseDiagnosis(session)) or {}
  local coach = {
    profileId = profile.id,
    wasteLines = {},
    waste = {},
    setImpact = {},
    nextTest = nil,
    compareHints = {},
  }
  if not session then
    coach.wasteLines[1] = "No fight selected"
    return coach
  end

  local snap = (type(session.playerStatsEnd) == "table") and session.playerStatsEnd
    or (type(session.playerStats) == "table") and session.playerStats
    or nil
  local penP, penS = 0, 0
  if snap and snap.buffed then
    penP = tonumber(snap.buffed.penPhysical) or 0
    penS = tonumber(snap.buffed.penSpell) or 0
  end
  local personalPen = math.max(penP, penS)
  local resistTarget = tonumber(profile.bossResist) or PEN_TARGET_LIGHT

  -- Group reduction (trial-prep assumptions + self-applied where seen)
  local groupPen = 0
  local groupBits = {}
  local groupConf = CONFIDENCE.ESTIMATED
  local majBreachUp, majBreachName = debuffUptimeByNameKey(session, "major breach")
  if majBreachUp < 0.05 then majBreachUp, majBreachName = buffUptimeByNameKey(session, "major breach") end
  local minBreachUp = debuffUptimeByNameKey(session, "minor breach")
  local crusherUp = debuffUptimeByNameKey(session, "crusher")
  if crusherUp < 0.05 then crusherUp = buffUptimeByNameKey(session, "crusher") end

  if profile.assumeMajorBreach then
    groupPen = groupPen + MAJOR_BREACH_PEN
    groupBits[#groupBits + 1] = "Major Breach (assumed)"
  elseif majBreachUp >= 0.25 then
    groupPen = groupPen + MAJOR_BREACH_PEN * math.min(1, majBreachUp)
    groupBits[#groupBits + 1] = string.format("Major Breach you applied %s", fmtPct(majBreachUp))
    groupConf = CONFIDENCE.OBSERVED
  end
  if minBreachUp >= 0.25 then
    groupPen = groupPen + MINOR_BREACH_PEN * math.min(1, minBreachUp)
    groupBits[#groupBits + 1] = string.format("Minor Breach %s", fmtPct(minBreachUp))
  end
  if profile.assumeCrusher then
    groupPen = groupPen + CRUSHER_PEN_GOLD
    groupBits[#groupBits + 1] = "Crusher (assumed)"
    if groupConf == CONFIDENCE.OBSERVED then groupConf = CONFIDENCE.ESTIMATED end
  elseif crusherUp >= 0.25 then
    groupPen = groupPen + CRUSHER_PEN_GOLD * math.min(1, crusherUp)
    groupBits[#groupBits + 1] = string.format("Crusher %s", fmtPct(crusherUp))
  end

  local effectivePen = personalPen + groupPen
  local remaining = math.max(0, resistTarget - effectivePen)
  local overPen = math.max(0, effectivePen - resistTarget)
  coach.waste.pen = {
    personal = personalPen,
    penPhys = penP,
    penSpell = penS,
    groupEst = groupPen,
    effective = effectivePen,
    remaining = remaining,
    overPen = overPen,
    resistTarget = resistTarget,
    confidence = groupConf,
  }

  -- Crit damage / Force
  local critDmgPct = sheetCritDmgPercent(snap)
  local majForceUp = buffUptimeByNameKey(session, "major force")
  local minForceUp = buffUptimeByNameKey(session, "minor force")
  local ceiling = (tonumber(profile.critDamageCeiling) or 1.25) * 100
  local overcapRisk = false
  local riskReason = ""
  if critDmgPct > 0 and critDmgPct >= ceiling - 2 then
    overcapRisk = true
    riskReason = "sheet already near ceiling"
  elseif profile.assumeMajorForce and (majForceUp >= 0.5 or critDmgPct >= 100) then
    overcapRisk = true
    riskReason = "trial-prep assumes group Major Force"
  elseif majForceUp >= 0.7 and critDmgPct >= 110 then
    overcapRisk = true
    riskReason = "high Major Force uptime with high sheet crit damage"
  end
  -- Prefer session-persisted exposure; re-finalize with profile ceiling
  local exposure = session.critDmgExposure
  if type(exposure) ~= "table" then
    exposure = finalizeCritDmgExposure(session, profile)
  else
    -- Re-run so profile ceiling matches current settings when viewing history
    exposure = finalizeCritDmgExposure(session, profile) or exposure
  end
  if type(exposure) == "table" then session.critDmgExposure = exposure end
  -- Prefer mid-fight avg over static sheet for overcap risk when available
  local avgSample = exposure and tonumber(exposure.avgSheetCritPct) or 0
  if avgSample > 0 and critDmgPct <= 0 then critDmgPct = avgSample end
  if avgSample >= ceiling - 2 then
    overcapRisk = true
    riskReason = "mid-fight samples near ceiling"
  end
  coach.waste.critDmg = {
    sheetPct = critDmgPct,
    ceilingPct = ceiling,
    majorForceUptime = majForceUp,
    minorForceUptime = minForceUp,
    overcapRisk = overcapRisk,
    riskReason = riskReason,
    exposure = exposure,
    exposureConf = (exposure and exposure.confidence) or CONFIDENCE.INSUFFICIENT,
  }

  -- Waste lines for Insights §2
  -- Crit *rate* (hits) is Observed from combat; crit *damage mult* is a different sheet stat.
  local lines = coach.wasteLines
  local hitCrit = sessionCritPct(session)
  if hitCrit > 0 then
    lines[#lines + 1] = string.format(
      "Crit rate (hits): %s of damage events crit  %s",
      fmtPct(hitCrit), confidenceChip(CONFIDENCE.OBSERVED)
    )
  end
  if critDmgPct > 0 then
    lines[#lines + 1] = string.format(
      "Crit damage mult (sheet): %0.0f%%  ·  ceiling %0.0f%%  %s",
      critDmgPct, ceiling, confidenceChip(CONFIDENCE.OBSERVED)
    )
  else
    -- Console rarely exposes STAT_CRITICAL_DAMAGE. Recipe from Force/Brittle/CP/racial.
    local rec = estimateCritDamageRecipe(session, profile)
    local headroom = math.max(0, (rec.ceiling or 125) - (rec.pct or 50))
    lines[#lines + 1] = string.format(
      "Crit dmg recipe: ~%0.0f%% of %0.0f%% cap (%s headroom)  ·  %s  %s",
      rec.pct or 50, rec.ceiling or 125,
      (headroom <= 0) and "at/over" or string.format("+%0.0f", headroom),
      rec.recipeTxt or "base 50",
      confidenceChip(CONFIDENCE.ESTIMATED)
    )
    if rec.over and rec.over > 0.5 then
      overcapRisk = true
      riskReason = "recipe over ceiling"
    end
  end
  -- Only show sheet mult / exposure lines when we have data; skip permanent Insufficient spam
  lines[#lines + 1] = string.format(
    "Major Force uptime %s  ·  Minor Force %s  %s%s",
    fmtPct(majForceUp), fmtPct(minForceUp),
    confidenceChip(CONFIDENCE.OBSERVED),
    overcapRisk and string.format("  ·  overcap risk (%s) %s", riskReason, confidenceChip(CONFIDENCE.ESTIMATED)) or ""
  )
  if exposure and exposure.confidence ~= CONFIDENCE.INSUFFICIENT and (tonumber(exposure.samples) or 0) > 0 then
    local overPct = (tonumber(exposure.overcapExposure) or 0) * 100
    local capU = tonumber(exposure.capUptime) or 0
    if overPct < 0.05 and capU < 0.05 then
      lines[#lines + 1] = string.format(
        "Crit-dmg exposure (sheet samples): avg %0.0f%% · under ceiling  %s",
        tonumber(exposure.avgSheetCritPct) or 0,
        confidenceChip(exposure.confidence or CONFIDENCE.ESTIMATED)
      )
    else
      lines[#lines + 1] = string.format(
        "Crit-dmg exposure (sheet samples): avg %0.0f%% · at/over cap %s · overcap ~%0.1f%%  %s",
        tonumber(exposure.avgSheetCritPct) or 0,
        fmtPct(capU),
        overPct,
        confidenceChip(exposure.confidence or CONFIDENCE.ESTIMATED)
      )
    end
  end

  -- Phase 2.5.2b: CP A/B pairs + attach marginals to synergy CP list
  local abPairs = findCpAbPairs(12)
  applyCpAbMarginals(syn, abPairs)
  coach.cpAbPairs = abPairs
  coach.syn = syn
  if #abPairs > 0 then
    local p = abPairs[1]
    -- Prefer a star that has multi-pair median if present
    local conf = CONFIDENCE.ESTIMATED
    for _, c in ipairs(syn.cps or {}) do
      if c.marginalConf == CONFIDENCE.OBSERVED then conf = CONFIDENCE.OBSERVED; break end
    end
    coach.cpAbHint = string.format(
      "CP A/B: %s · ΔDPS %s  %s",
      p.swapLabel or "champion swap",
      fmtDpsDelta(p.deltaDps or 0),
      confidenceChip(conf)
    )
  end

  lines[#lines + 1] = string.format(
    "Penetration: phys %s · spell %s (personal max %s)  %s",
    fmtInt(penP), fmtInt(penS), fmtInt(personalPen), confidenceChip(CONFIDENCE.OBSERVED)
  )
  if #groupBits > 0 then
    lines[#lines + 1] = string.format(
      "Group resist reduction: %s (+%s est.)  %s",
      table.concat(groupBits, ", "),
      fmtInt(groupPen),
      confidenceChip(groupConf)
    )
  end
  -- Explicit recipe so players see what builds effective pen
  lines[#lines + 1] = string.format(
    "Effective pen recipe: personal %s + group %s = %s  (target resist %s)  %s",
    fmtInt(personalPen),
    fmtInt(groupPen),
    fmtInt(effectivePen),
    fmtInt(resistTarget),
    confidenceChip(CONFIDENCE.ESTIMATED)
  )
  if remaining <= 0 then
    lines[#lines + 1] = string.format(
      "At/over resist reference — extra personal pen likely low value under this profile  %s",
      confidenceChip(CONFIDENCE.ESTIMATED)
    )
  else
    lines[#lines + 1] = string.format(
      "About %s resist may remain if group assumptions hold  %s",
      fmtInt(remaining),
      confidenceChip(CONFIDENCE.ESTIMATED)
    )
  end
  coach.waste.pen.recipeLine = lines[#lines - 1]
  coach.waste.pen.groupBits = groupBits

  -- Support brought
  local supportBits = {}
  if type(session.buffs) == "table" then
    for _, b in pairs(session.buffs) do
      if type(b) == "table" then
        local hint = buffEffectHint(b.name)
        local srcKey = classifyBuffSourceDetailed(session, b)
        if hint and (srcKey == "Skill" or srcKey == "Self" or srcKey == "Set" or srcKey == "Group") then
          supportBits[#supportBits + 1] = string.format("%s (%s)", b.name or "?", hint.detail or hint.tag or "?")
        end
      end
    end
  end
  table.sort(supportBits)
  if #supportBits > 0 then
    lines[#lines + 1] = "Support you brought: " .. table.concat(supportBits, "  ·  ")
  else
    lines[#lines + 1] = "Support you brought: none matched — see Buffs for the full list."
  end

  -- Set impact (direct + buff-mediated notes)
  local total = tonumber(syn.totalDmg) or tonumber(session.totalDamage) or 0
  local dur = tonumber(session.durationMs) or 0
  local setArr = {}
  if type(session.sets) == "table" then
    for _, ps in pairs(session.sets) do
      if type(ps) == "table" then setArr[#setArr + 1] = ps end
    end
  end
  table.sort(setArr, function(a, b) return (tonumber(a.dmg) or 0) > (tonumber(b.dmg) or 0) end)
  local equipped = {}
  if type(session.equippedSets) == "table" then
    for _, n in ipairs(session.equippedSets) do equipped[#equipped + 1] = tostring(n) end
  end
  -- Also list equipped sets with 0 direct damage
  local seenSet = {}
  for _, ps in ipairs(setArr) do
    local name = tostring(ps.name or "?")
    seenSet[string.lower(name)] = true
    local dmg = tonumber(ps.dmg) or 0
    local share = total > 0 and (dmg / total) or 0
    local dps = dur > 0 and (dmg / (dur / 1000)) or 0
    local buffNotes = {}
    local nlow = string.lower(name)
    -- Link common set-driven buffs by name overlap or Force if "balorgh" etc. — keep general
    for _, b in pairs(type(session.buffs) == "table" and session.buffs or {}) do
      if type(b) == "table" and b.name then
        local blow = string.lower(tostring(b.name))
        if nlow ~= "" and (string.find(blow, nlow, 1, true) or string.find(nlow, blow, 1, true)) then
          local up = dur > 0 and ((tonumber(b.activeMs) or 0) / dur) or 0
          buffNotes[#buffNotes + 1] = string.format("%s %s", b.name, fmtPct(up))
        end
      end
    end
    coach.setImpact[#coach.setImpact + 1] = {
      name = name,
      directDmg = dmg,
      directDps = dps,
      directShare = share,
      buffNotes = buffNotes,
      confidence = CONFIDENCE.OBSERVED,
      marginalConf = CONFIDENCE.INSUFFICIENT,
    }
  end
  for _, en in ipairs(equipped) do
    if not seenSet[string.lower(en)] then
      coach.setImpact[#coach.setImpact + 1] = {
        name = en,
        directDmg = 0,
        directDps = 0,
        directShare = 0,
        buffNotes = {},
        confidence = CONFIDENCE.OBSERVED,
        note = "No direct proc damage attributed — may be buff-mediated or unmeasurable",
        marginalConf = CONFIDENCE.INSUFFICIENT,
      }
    end
  end

  -- Next Test (Phase 2.5 priority)
  local comparables = 0
  if diag.bench then comparables = tonumber(diag.bench.comparableCount) or 0 end
  local softCp = nil
  for _, c in ipairs(syn.cps or {}) do
    if c.fitKey == "soft" then softCp = c break end
  end
  local topOpp = diag.opportunities and diag.opportunities[1] or nil
  local topOppDps = topOpp and (tonumber(topOpp.estDps) or 0) or 0

  if comparables < 2 then
    coach.nextTest = {
      title = "Build sample size first",
      body = string.format(
        "Run at least two more full parses on the same target with this build fixed. DM2 needs comparable runs before a controlled swap. %s",
        confidenceChip(CONFIDENCE.INSUFFICIENT)
      ),
      confidence = CONFIDENCE.INSUFFICIENT,
      ruleId = "sample_size",
      actionHint = "",
    }
  elseif topOppDps >= 2000 then
    coach.nextTest = {
      title = "Address top recovery opportunity",
      body = string.format(
        "%s  Keep gear, bars, Mundus, and Champion Points unchanged. Complete three full parses on the same target; compare median DPS and this opportunity. %s",
        topOpp.drill or topOpp.title or "Focus the top estimated recovery",
        confidenceChip(CONFIDENCE.ESTIMATED)
      ),
      confidence = CONFIDENCE.ESTIMATED,
      ruleId = "execution_opp",
      actionHint = "Footer A/× : Start experiment (3 parses)",
    }
  elseif remaining <= 0 and personalPen > resistTarget + 2000 then
    coach.nextTest = {
      title = "Test less personal penetration",
      body = string.format(
        "Under %s, effective pen is at/over boss reference (%s). Try a non-pen offensive line (keep bars fixed) for three full parses; compare median DPS and the Penetration waste lines. %s",
        profile.label or "Trial-prep dummy",
        fmtInt(resistTarget),
        confidenceChip(CONFIDENCE.ESTIMATED)
      ),
      confidence = CONFIDENCE.ESTIMATED,
      ruleId = "pen_waste",
      actionHint = "Footer A/× : Start experiment (3 parses)",
    }
  elseif overcapRisk then
    coach.nextTest = {
      title = "Test critical-damage stacking",
      body = string.format(
        "Overcap risk flagged (%s). Keep bars/sets fixed where possible; reduce a crit-damage source (e.g. soft Champion Point or redundant Force path) and run three full parses. Compare median DPS and Force uptime. %s",
        riskReason,
        confidenceChip(CONFIDENCE.ESTIMATED)
      ),
      confidence = CONFIDENCE.ESTIMATED,
      ruleId = "crit_overcap_risk",
      actionHint = "Footer A/× : Start experiment (3 parses)",
    }
  elseif softCp then
    coach.nextTest = {
      title = "Review soft Champion Point fit",
      body = string.format(
        "\"%s\" ranked Soft — eligible about %s of this parse (%s). Keep gear fixed; swap toward a star matching your Direct/DoT/crit shape, then three full parses. %s",
        softCp.name or "Champion star",
        fmtPct(softCp.eligiblePct or 0),
        softCp.eligibleNote or softCp.reason or "parse mix",
        confidenceChip(CONFIDENCE.ESTIMATED)
      ),
      confidence = CONFIDENCE.ESTIMATED,
      ruleId = "soft_cp",
      actionHint = "Footer A/× : Start experiment (3 parses)",
    }
  else
    coach.nextTest = {
      title = "Hold build; refine execution",
      body = string.format(
        "No high-confidence build swap under %s. Keep the same build fingerprint; improve weave, DoT uptime, and late-phase consistency across three more parses.",
        profile.label or "Trial-prep dummy"
      ),
      confidence = CONFIDENCE.ESTIMATED,
      ruleId = "hold_build",
      actionHint = "Footer A/× : Start experiment (3 parses)",
    }
  end

  -- Experiment progress (scaffold): show if active; results summary when complete
  local exp = getActiveExperiment()
  if exp and type(exp) == "table" then
    local runs = type(exp.runs) == "table" and exp.runs or {}
    local n = #runs
    local need = tonumber(exp.targetRuns) or 3
    coach.experiment = exp
    -- Simple run stats for results body (full History cohort is 2.5.5)
    local dpsMin, dpsMax, dpsSum = nil, nil, 0
    for _, run in ipairs(runs) do
      local d = tonumber(run.dps) or 0
      dpsSum = dpsSum + d
      if not dpsMin or d < dpsMin then dpsMin = d end
      if not dpsMax or d > dpsMax then dpsMax = d end
    end
    local dpsAvg = n > 0 and (dpsSum / n) or 0
    if exp.completed then
      local deltaTxt = ""
      if n >= 2 and dpsMin and dpsMax then
        deltaTxt = string.format(" · spread %s", fmtDpsDelta((dpsMax or 0) - (dpsMin or 0)))
      end
      coach.nextTest = {
        title = "Review experiment results",
        body = string.format(
          "Experiment complete (%d/%d): %s. Runs avg %s · min %s · max %s%s. Open History for cohort + EXP tags. Press Y to clear, then start a new Next Test. %s",
          n, need, exp.title or "",
          fmtDps(dpsAvg), fmtDps(dpsMin or 0), fmtDps(dpsMax or 0), deltaTxt,
          confidenceChip(n >= 3 and CONFIDENCE.OBSERVED or CONFIDENCE.ESTIMATED)
        ),
        confidence = n >= 3 and CONFIDENCE.OBSERVED or CONFIDENCE.ESTIMATED,
        ruleId = "experiment_done",
        actionHint = "Footer A/× : Clear experiment",
      }
    else
      coach.nextTest = {
        title = string.format("Experiment in progress (%d/%d)", n, need),
        body = string.format(
          "%s  %s  Remaining runs: %d.%s  %s",
          exp.title or "Controlled test",
          exp.holdHint or "Keep bars/sets/Mundus fixed.",
          math.max(0, need - n),
          (session.experimentWarn and ("  " .. session.experimentWarn)) or "",
          confidenceChip(CONFIDENCE.OBSERVED)
        ),
        confidence = CONFIDENCE.OBSERVED,
        ruleId = "experiment_active",
        actionHint = "Footer A/× : End experiment",
      }
    end
  elseif session.experimentWarn then
    coach.compareHints = coach.compareHints or {}
    coach.compareHints[#coach.compareHints + 1] = session.experimentWarn
  end

  return coach
end
M.BuildCoachAnalysis = buildCoachAnalysis

-- Gamepad keybind helpers (must sit below buildCoachAnalysis — no forward refs)
local function toggleExperimentFromUi(session)
  local exp = getActiveExperiment()
  if exp then
    clearActiveExperiment()
    return "cleared", nil
  end
  if type(session) ~= "table" then return nil, nil end
  local profile = getActiveContentProfile()
  -- Analyze without treating active experiment (we already know none)
  local coach = buildCoachAnalysis(session, nil, nil, profile)
  local nt = coach and coach.nextTest
  if type(nt) ~= "table" then return nil, nil end
  if nt.ruleId == "sample_size" or nt.ruleId == "experiment_active" or nt.ruleId == "experiment_done" then
    return nil, nt
  end
  local started = startExperimentFromNextTest(session, nt, profile)
  if started then
    tryAttachExperimentRun(session)
  end
  return started and "started" or nil, nt
end
M.ToggleExperimentFromUi = toggleExperimentFromUi

local function experimentKeybindName()
  local exp = getActiveExperiment()
  if exp then
    local n = type(exp.runs) == "table" and #exp.runs or 0
    local need = tonumber(exp.targetRuns) or 3
    if exp.completed then return string.format("Clear Exp (done %d/%d)", n, need) end
    return string.format("End Exp (ON %d/%d)", n, need)
  end
  return "Start Experiment"
end

local function experimentKeybindEnabled()
  if getActiveExperiment() then return true end
  if not screenObject or screenObject.currentTab ~= TAB.INSIGHTS_DPS then return false end
  local session = historyAt(historyOffset)
  return type(session) == "table"
end

-- Fingerprint cohort for History strip (2.5.5)
local function buildFingerprintCohort(session)
  local fp = session and (session.buildFingerprint or (session.build and session.build.fingerprint))
  if not fp or fp == "" then return nil end
  local dpsList, weaveList = {}, {}
  local count = historyCount()
  for i = 0, count - 1 do
    local s = historyAt(i)
    if s and s.isDummy then
      local sfp = s.buildFingerprint or (s.build and s.build.fingerprint)
      if sfp == fp then
        dpsList[#dpsList + 1] = sessionAvgDps(s)
        weaveList[#weaveList + 1] = getWeaveSuccessRatio(s)
      end
    end
  end
  local n = #dpsList
  if n <= 0 then return nil end
  local best, worst = dpsList[1], dpsList[1]
  for i = 2, n do
    if dpsList[i] > best then best = dpsList[i] end
    if dpsList[i] < worst then worst = dpsList[i] end
  end
  return {
    fingerprint = fp,
    n = n,
    medianDps = medianOf(dpsList),
    bestDps = best,
    worstDps = worst,
    medianWeave = medianOf(weaveList),
  }
end
M.BuildFingerprintCohort = buildFingerprintCohort

local function collectDummyTrendParses(maxCols)
  maxCols = tonumber(maxCols) or TREND_MAX_COLS
  local arr = {}
  local count = historyCount()
  for offset = 0, count - 1 do
    local s = historyAt(offset)
    if s and s.isDummy then
      local dur = tonumber(s.durationMs) or 0
      local hits = tonumber(s.hitCount) or 0
      table.insert(arr, {
        offset = offset,
        dps = dur > 0 and ((tonumber(s.totalDamage) or 0) / (dur / 1000)) or 0,
        crit = hits > 0 and ((tonumber(s.critCount) or 0) / hits) or 0,
        weave = getWeaveSuccessRatio(s),
        session = s,
      })
      if #arr >= maxCols then break end
    end
  end
  return arr
end

-- Structured history cards for decorated list UI.
local function buildHistoryCards(activeOffset, maxCards)
  maxCards = tonumber(maxCards) or TREND_HIST_LINES
  activeOffset = tonumber(activeOffset) or 0
  local cards = {}
  local count = historyCount()
  if count <= 0 then return cards end
  local exp = getActiveExperiment()
  local startOffset = math.max(0, activeOffset - 2)
  local endOffset = math.min(count - 1, startOffset + maxCards - 1)
  for offset = startOffset, endOffset do
    local s = historyAt(offset)
    if s then
      local fightNo = fightNumberFromOffset(offset, count)
      local target = truncateText(s.lastTargetName or "?", 50)
      local tag = s.isDummy and "DUMMY" or "WORLD"
      local er = s.experimentRun
      if type(er) == "table" and er.runIndex then
        tag = string.format("EXP%d", tonumber(er.runIndex) or 0)
      elseif exp and type(exp.runs) == "table" then
        local sfp = s.buildFingerprint or (s.build and s.build.fingerprint)
        for _, run in ipairs(exp.runs) do
          if run.completedAt and s.completedAt and run.completedAt == s.completedAt then
            tag = string.format("EXP%d", tonumber(run.runIndex) or 0)
            break
          end
          if sfp and run.fingerprint and run.fingerprint == sfp and s.isDummy then
            -- soft match for runs without completedAt link
          end
        end
      end
      cards[#cards + 1] = {
        offset = offset,
        selected = (offset == activeOffset),
        fightNo = fightNo,
        target = target,
        isDummy = s.isDummy == true,
        isExp = type(er) == "table",
        dps = fmtDps(sessionAvgDps(s)),
        crit = fmtPct(sessionCritPct(s)),
        weave = fmtPct(getWeaveSuccessRatio(s)),
        dur = fmtDur(s.durationMs),
        when = formatSessionTimestampShort(s),
        tag = tag,
      }
    end
  end
  return cards
end

-- Comparison as row-major table model: headers[1..n], rows[{label, cells[1..n]}]
-- Phase 2: include build fingerprint + basic deltas between col1 (newest) and others
local function buildComparisonTable(maxCols)
  maxCols = tonumber(maxCols) or COMP_COLS
  local dummies = {}
  local count = historyCount()
  for offset = 0, count - 1 do
    local s = historyAt(offset)
    if s and s.isDummy then
      dummies[#dummies + 1] = s
      if #dummies >= maxCols then break end
    end
  end
  -- dummies[1] is newest (offset 0). #1 = newest everywhere.
  local headers = {}
  for i, s in ipairs(dummies) do
    local fp = s.buildFingerprint or (s.build and s.build.fingerprint)
    local fpShort = fp and string.sub(tostring(fp), 1, 6) or "no-fp"
    headers[i] = string.format("#%d %s", i, truncateText(s.lastTargetName or "dummy", 22))
    if fp then
      headers[i] = headers[i] .. " " .. fpShort
    end
  end
  if #dummies == 0 then
    return headers, { { label = "No dummy parses yet", cells = {} } }
  end
  local function fpOf(s)
    return s.buildFingerprint or (s.build and s.build.fingerprint) or "—"
  end
  local metrics = {
    { "Build ID", function(s) return string.sub(tostring(fpOf(s)), 1, 8) end },
    { "Avg DPS", function(s) return fmtDps(sessionAvgDps(s)) end },
    { "Crit %", function(s) return fmtPct(sessionCritPct(s)) end },
    { "Weave %", function(s) return fmtPct(getWeaveSuccessRatio(s)) end },
    { "Duration", function(s) return fmtDur(s.durationMs) end },
    { "Total Dmg", function(s) return fmtInt(s.totalDamage) end },
    { "LA Hits", function(s) return tostring(sessionLaHits(s)) end },
    { "Max Hit", function(s) return fmtInt(s.maxHit) end },
  }
  local rows = {}
  for _, m in ipairs(metrics) do
    local cells = {}
    for i, s in ipairs(dummies) do cells[i] = m[2](s) end
    rows[#rows + 1] = { label = m[1], cells = cells }
  end
  -- Newest (#1) vs Fight #2 only — signed deltas, no trailing "vs #2" (row label owns that)
  if #dummies >= 2 then
    local a, b = dummies[1], dummies[2]
    local dpsA, dpsB = sessionAvgDps(a), sessionAvgDps(b)
    local dDps = dpsA - dpsB
    local sameFp = fpOf(a) ~= "—" and fpOf(a) == fpOf(b)
    local causeCells = {}
    for i = 1, #dummies do causeCells[i] = "" end
    local bits = {}
    if sameFp then
      bits[#bits + 1] = "same build"
    else
      local pa = a.buildFpParts or (a.build and a.build.fpParts)
      local pb = b.buildFpParts or (b.build and b.build.fpParts)
      if type(pa) == "table" and type(pb) == "table" then
        local diffs = {}
        if pa.f ~= pb.f or pa.b ~= pb.b then diffs[#diffs + 1] = "bars" end
        if pa.s ~= pb.s then diffs[#diffs + 1] = "sets" end
        if pa.m ~= pb.m then diffs[#diffs + 1] = "mundus" end
        if pa.c ~= pb.c then diffs[#diffs + 1] = "CP" end
        if #diffs > 0 then
          bits[#bits + 1] = "build " .. table.concat(diffs, "/")
        else
          bits[#bits + 1] = "build differs"
        end
      else
        bits[#bits + 1] = "build differs"
      end
    end
    local laA, laB = sessionLaHits(a), sessionLaHits(b)
    if laA ~= laB then
      local dLa = laA - laB
      bits[#bits + 1] = string.format("LA %+d", dLa)
    end
    local wA, wB = getWeaveSuccessRatio(a), getWeaveSuccessRatio(b)
    if math.abs(wA - wB) >= 0.02 then
      bits[#bits + 1] = string.format("weave %+0.0f%%", (wA - wB) * 100)
    end
    local setA, setB = 0, 0
    if type(a.sets) == "table" then
      for _, ps in pairs(a.sets) do setA = setA + (tonumber(ps.dmg) or 0) end
    end
    if type(b.sets) == "table" then
      for _, ps in pairs(b.sets) do setB = setB + (tonumber(ps.dmg) or 0) end
    end
    local durA = math.max(1, (tonumber(a.durationMs) or 0) / 1000)
    local durB = math.max(1, (tonumber(b.durationMs) or 0) / 1000)
    local setDpsDelta = (setA / durA) - (setB / durB)
    if math.abs(setDpsDelta) >= 500 then
      bits[#bits + 1] = "set-proc " .. fmtDpsDelta(setDpsDelta)
    end
    bits[#bits + 1] = "DPS " .. fmtDpsDelta(dDps)
    causeCells[1] = table.concat(bits, " · ")
    -- Fight #2 column: pointer only (row label is already "vs Fight #2")
    causeCells[2] = "←"
    rows[#rows + 1] = { label = "vs Fight #2", cells = causeCells }
  end
  return headers, rows
end

local function resolveSession()
  local count = historyCount()
  historyOffset = clampHistoryOffset(historyOffset, count)
  local session = count > 0 and historyAt(historyOffset) or nil
  if type(session) ~= "table" then
    headerNote = "No fights in history — parse a dummy, then reopen"
    return nil, 0
  end
  local target = truncateText(session.lastTargetName or "fight", 36)
  local tag = session.isDummy and "dummy" or "world"
  local fightNo = fightNumberFromOffset(historyOffset, count)
  local when = string.format("#%d/%d", fightNo, count)
  if historyOffset == 0 then when = when .. " latest" end
  headerNote = string.format("%s %s (%s) · L2/R2 history", when, target, tag)
  return session, count
end

local function sectionLabelForTab(tabIndex)
  tabIndex = tonumber(tabIndex) or TAB.OVERVIEW
  for _, entry in ipairs(NAV_ENTRIES) do
    if entry.tab == tabIndex then return entry.label end
  end
  return "Overview"
end

---------------------------------------------------------------------
-- Draw / layout helpers + all menu UI
-- Installed via nested function so UI locals use a separate 200-local pool
-- (ESO Lua 5.1 main-chunk limit). Early coach/helpers stay outside.
---------------------------------------------------------------------
local function installMenuUI()
local function stampBackground(ctrl, level)
  if not ctrl then return end
  level = tonumber(level) or 0
  if type(ctrl.SetDrawLayer) == "function" then
    if type(DL_BACKGROUND) ~= "nil" then ctrl:SetDrawLayer(DL_BACKGROUND)
    elseif type(DL_CONTROLS) ~= "nil" then ctrl:SetDrawLayer(DL_CONTROLS) end
  end
  if type(ctrl.SetDrawTier) == "function" then
    if type(DT_LOW) ~= "nil" then ctrl:SetDrawTier(DT_LOW)
    elseif type(DT_MEDIUM) ~= "nil" then ctrl:SetDrawTier(DT_MEDIUM) end
  end
  if type(ctrl.SetDrawLevel) == "function" then ctrl:SetDrawLevel(level) end
end

local function stampForeground(ctrl, level)
  if not ctrl then return end
  level = tonumber(level) or 100
  if type(ctrl.SetDrawLayer) == "function" then
    if type(DL_TEXT) ~= "nil" then ctrl:SetDrawLayer(DL_TEXT)
    elseif type(DL_CONTROLS) ~= "nil" then ctrl:SetDrawLayer(DL_CONTROLS) end
  end
  if type(ctrl.SetDrawTier) == "function" then
    if type(DT_HIGH) ~= "nil" then ctrl:SetDrawTier(DT_HIGH)
    elseif type(DT_MEDIUM) ~= "nil" then ctrl:SetDrawTier(DT_MEDIUM) end
  end
  if type(ctrl.SetDrawLevel) == "function" then ctrl:SetDrawLevel(level) end
end

local function makeDashLabel(parent, name, size, r, g, b, a)
  local lbl = WM:CreateControl(name, parent, CT_LABEL)
  if type(lbl.SetFont) == "function" then lbl:SetFont(dashFont(size)) end
  lbl:SetColor(r or THEME.textR, g or THEME.textG, b or THEME.textB, a or 1)
  lbl:SetVerticalAlignment(TEXT_ALIGN_TOP)
  lbl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
  lbl:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
  stampForeground(lbl, 120)
  return lbl
end

local function makeSectionFrame(parent, name, solid)
  local bg = WM:CreateControl(name, parent, CT_BACKDROP)
  if solid == false then
    bg:SetCenterColor(THEME.cardR, THEME.cardG, THEME.cardB, THEME.cardA * 0.55)
    bg:SetEdgeColor(THEME.cardEdgeR, THEME.cardEdgeG, THEME.cardEdgeB, THEME.cardEdgeA * 0.7)
  else
    bg:SetCenterColor(THEME.cardR, THEME.cardG, THEME.cardB, THEME.cardA)
    bg:SetEdgeColor(THEME.cardEdgeR, THEME.cardEdgeG, THEME.cardEdgeB, THEME.cardEdgeA)
  end
  bg:SetInsets(2, 2, -2, -2)
  stampBackground(bg, 2)
  return bg
end

local function forceControlRect(ctrl, parent, left, top, width, height)
  if not ctrl then return end
  if type(ctrl.ClearAnchors) == "function" then ctrl:ClearAnchors() end
  if type(ctrl.SetAnchor) == "function" and parent then
    ctrl:SetAnchor(TOPLEFT, parent, TOPLEFT, left, top)
  end
  if type(ctrl.SetDimensions) == "function" then
    ctrl:SetDimensions(width, height)
  else
    if type(ctrl.SetWidth) == "function" then ctrl:SetWidth(width) end
    if type(ctrl.SetHeight) == "function" then ctrl:SetHeight(height) end
  end
  if type(ctrl.SetHidden) == "function" then ctrl:SetHidden(false) end
end

local function sparkColorForRatio(ratio)
  if ratio > 0.72 then return 0.45, 0.88, 0.48, 0.94 end
  if ratio > 0.42 then return 0.92, 0.72, 0.32, 0.92 end
  return 0.88, 0.38, 0.30, 0.90
end

local function layoutSparkBars(bars, wrap, values, wrapW, maxH, maxBars)
  maxH = maxH or SPARK_BAR_MAX_H
  maxBars = maxBars or SPARK_MAX_BARS
  bars = bars or {}
  values = values or {}
  wrapW = tonumber(wrapW) or 200
  local count = math.min(#values, maxBars, #bars)
  local maxVal = 1
  for i = 1, count do
    local v = tonumber(values[i]) or 0
    if v > maxVal then maxVal = v end
  end
  local barW = math.max(5, math.floor((wrapW - 4) / math.max(count, 1)) - 2)
  for i, bar in ipairs(bars) do
    if not bar then
      -- skip
    elseif i <= count then
      local v = tonumber(values[i]) or 0
      local ratio = (maxVal > 0) and (v / maxVal) or 0
      local h = math.max(3, math.floor(ratio * maxH))
      bar:ClearAnchors()
      bar:SetDimensions(barW, h)
      if wrap then bar:SetAnchor(BOTTOMLEFT, wrap, BOTTOMLEFT, (i - 1) * (barW + 2), 0) end
      local r, g, b, a = sparkColorForRatio(ratio)
      bar:SetCenterColor(r, g, b, a)
      bar:SetHidden(false)
    else
      bar:SetHidden(true)
    end
  end
end

local function createSparkBarPool(parent, namePrefix, count)
  local wrap = WM:CreateControl(namePrefix .. "Wrap", parent, CT_CONTROL)
  stampForeground(wrap, 90)
  local bars = {}
  for i = 1, count do
    local bar = WM:CreateControl(namePrefix .. i, wrap, CT_BACKDROP)
    bar:SetCenterColor(0.3, 0.7, 1.0, 0.9)
    bar:SetEdgeColor(0, 0, 0, 0)
    bar:SetHidden(true)
    stampForeground(bar, 95)
    bars[i] = bar
  end
  return wrap, bars
end

local function resolveShellRects()
  local rootW = GuiRoot and GuiRoot:GetWidth() or 1920
  local rootH = GuiRoot and GuiRoot:GetHeight() or 1080
  local top = CONTENT_HEADER_INSET
  local usableH = math.max(320, rootH - top - CONTENT_FOOTER_INSET)
  local navW = floorNum(rootW * NAV_RAIL_FRAC)
  if type(ZO_GAMEPAD_CONTENT_LEFT_OFFSET) == "number" and ZO_GAMEPAD_CONTENT_LEFT_OFFSET > 120
      and ZO_GAMEPAD_CONTENT_LEFT_OFFSET < (rootW * 0.38) then
    navW = ZO_GAMEPAD_CONTENT_LEFT_OFFSET
  end
  navW = clampNum(navW, NAV_RAIL_MIN, NAV_RAIL_MAX)
  local navLeft = SHELL_SIDE_PAD
  local contentLeft = navLeft + navW + NAV_CONTENT_GAP
  local contentW = math.max(420, rootW - contentLeft - SHELL_SIDE_PAD)
  return {
    rootW = rootW, rootH = rootH,
    navLeft = navLeft, navTop = top, navW = navW, navH = usableH,
    contentLeft = contentLeft, contentTop = top, contentW = contentW, contentH = usableH,
  }
end

local function getNavListControl(screen)
  local list = screen and screen.navList
  if not list then return nil end
  return list.control or list.list or list
end

---------------------------------------------------------------------
-- Generic icon+meta list (shared by Damage / Buffs / Procs / Weave)
---------------------------------------------------------------------
local function createIconRowList(parent, namePrefix, maxRows, iconSize)
  maxRows = tonumber(maxRows) or LIST_MAX_ROWS
  iconSize = tonumber(iconSize) or LIST_ICON
  local ui = { rows = {}, maxRows = maxRows, iconSize = iconSize }
  ui.title = makeDashLabel(parent, namePrefix .. "Title", 15, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.title:SetAnchor(TOPLEFT, parent, TOPLEFT, CONTENT_PAD, 8)
  ui.meta = makeDashLabel(parent, namePrefix .. "Meta", 14, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.meta:SetAnchor(TOPLEFT, ui.title, BOTTOMLEFT, 0, 4)
  ui.legend = makeDashLabel(parent, namePrefix .. "Legend", 13, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.legend:SetAnchor(TOPLEFT, ui.meta, BOTTOMLEFT, 0, 2)
  ui.legend:SetText("|c88DDAAF|r Front bar   |c88AADDB|r Back bar")
  local y0 = 58
  for i = 1, maxRows do
    local row = WM:CreateControl(namePrefix .. "Row" .. i, parent, CT_CONTROL)
    row:SetAnchor(TOPLEFT, parent, TOPLEFT, CONTENT_PAD, y0 + ((i - 1) * LIST_ROW_H))
    row:SetDimensions(400, LIST_ROW_H - 4)
    local chip = makeDashLabel(row, namePrefix .. "Chip" .. i, 14, THEME.frontR, THEME.frontG, THEME.frontB, 1)
    chip:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 10)
    chip:SetDimensions(16, 18)
    local icon = WM:CreateControl(namePrefix .. "Icon" .. i, row, CT_TEXTURE)
    icon:SetDimensions(iconSize, iconSize)
    icon:SetAnchor(TOPLEFT, row, TOPLEFT, 20, 4)
    stampForeground(icon, 110)
    local shareBg = WM:CreateControl(namePrefix .. "ShareBg" .. i, row, CT_BACKDROP)
    shareBg:SetCenterColor(0.12, 0.12, 0.14, 0.55)
    shareBg:SetEdgeColor(0, 0, 0, 0)
    shareBg:SetAnchor(TOPLEFT, row, TOPLEFT, 20 + iconSize + 8, 36)
    shareBg:SetDimensions(200, 6)
    stampBackground(shareBg, 5)
    local shareFg = WM:CreateControl(namePrefix .. "ShareFg" .. i, shareBg, CT_BACKDROP)
    shareFg:SetCenterColor(0.55, 0.78, 0.42, 0.9)
    shareFg:SetEdgeColor(0, 0, 0, 0)
    shareFg:SetAnchor(TOPLEFT, shareBg, TOPLEFT, 0, 0)
    shareFg:SetDimensions(2, 6)
    stampForeground(shareFg, 100)
    local nameLbl = makeDashLabel(row, namePrefix .. "Name" .. i, 16, THEME.textR, THEME.textG, THEME.textB, 1)
    nameLbl:SetAnchor(TOPLEFT, row, TOPLEFT, 20 + iconSize + 8, 2)
    local subLbl = makeDashLabel(row, namePrefix .. "Sub" .. i, 13, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
    subLbl:SetAnchor(TOPLEFT, nameLbl, BOTTOMLEFT, 0, 1)
    ui.rows[i] = {
      row = row, chip = chip, icon = icon, name = nameLbl, sub = subLbl,
      shareBg = shareBg, shareFg = shareFg,
    }
  end
  ui.empty = makeDashLabel(parent, namePrefix .. "Empty", 16, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.empty:SetAnchor(TOPLEFT, parent, TOPLEFT, CONTENT_PAD, y0)
  ui.empty:SetHidden(true)
  return ui
end

local function layoutIconRowList(ui, hostW, hostH)
  if not ui then return end
  local pad = CONTENT_PAD
  local W = math.max(400, (hostW or 800) - pad * 2)
  local H = math.max(300, (hostH or 600) - 12)
  if ui.title then ui.title:SetWidth(W) end
  if ui.meta then ui.meta:SetWidth(W) end
  if ui.legend then ui.legend:SetWidth(W) end
  if ui.empty then ui.empty:SetWidth(W) end

  -- Pack: icon+name | sub metrics | share bar (no giant empty middle).
  local iconSize = ui.iconSize or LIST_ICON
  local leftX = 20 + iconSize + 8
  local nameW = math.min(300, math.max(170, math.floor(W * 0.32)))
  local barW = math.min(240, math.max(140, math.floor(W * 0.24)))
  local subW = math.max(140, W - leftX - nameW - barW - 28)
  local y0 = 56
  local maxRows = ui.maxRows or LIST_MAX_ROWS
  local avail = H - y0 - 8
  local rowH = math.floor(avail / maxRows)
  if rowH < 34 then rowH = 34 end
  if rowH > 44 then rowH = 44 end

  for i, r in ipairs(ui.rows or {}) do
    if r.row then
      local parent = r.row:GetParent()
      r.row:ClearAnchors()
      if parent then
        r.row:SetAnchor(TOPLEFT, parent, TOPLEFT, pad, y0 + (i - 1) * rowH)
      end
      r.row:SetDimensions(W, rowH - 2)
    end
    if r.name then
      r.name:ClearAnchors()
      r.name:SetAnchor(TOPLEFT, r.row, TOPLEFT, leftX, 2)
      r.name:SetWidth(nameW)
      r.name:SetMaxLineCount(1)
    end
    if r.sub then
      r.sub:ClearAnchors()
      r.sub:SetAnchor(TOPLEFT, r.row, TOPLEFT, leftX + nameW + 8, 4)
      r.sub:SetWidth(subW)
      r.sub:SetMaxLineCount(2)
    end
    if r.shareBg then
      r.shareBg:ClearAnchors()
      r.shareBg:SetAnchor(TOPRIGHT, r.row, TOPRIGHT, -6, math.floor((rowH - 10) / 2))
      r.shareBg:SetDimensions(barW, 10)
    end
  end
end

local function refreshIconRowList(ui, items, emptyText)
  if not ui then return end
  items = items or {}
  if #items == 0 then
    if ui.empty then
      ui.empty:SetText(emptyText or "No data for this fight.")
      ui.empty:SetHidden(false)
    end
    for _, r in ipairs(ui.rows or {}) do
      if r.row then r.row:SetHidden(true) end
    end
    return
  end
  if ui.empty then ui.empty:SetHidden(true) end
  for i, r in ipairs(ui.rows or {}) do
    local item = items[i]
    if item and r.row then
      r.row:SetHidden(false)
      if r.name then r.name:SetText(item.name or "?") end
      if r.sub then r.sub:SetText(item.sub or "") end
      if r.icon then
        if item.icon then
          r.icon:SetTexture(item.icon)
          r.icon:SetHidden(false)
          r.icon:SetColor(1, 1, 1, 1)
        else
          r.icon:SetHidden(true)
        end
      end
      if r.chip then
        local chip = barChipLabel(item.bar)
        r.chip:SetText(chip)
        local cr, cg, cb, ca = barChipColor(item.bar)
        r.chip:SetColor(cr, cg, cb, ca)
        r.chip:SetHidden(chip == "")
      end
      if r.shareBg and r.shareFg then
        local share = tonumber(item.share) or 0
        if share < 0 then share = 0 end
        if share > 1 then share = 1 end
        local bgW = r.shareBg:GetWidth() or 200
        if bgW < 10 then bgW = 200 end
        local fgW = math.max(2, math.floor(bgW * share))
        r.shareFg:SetDimensions(fgW, 6)
        r.shareBg:SetHidden(false)
        r.shareFg:SetHidden(false)
      end
    elseif r.row then
      r.row:SetHidden(true)
    end
  end
end

---------------------------------------------------------------------
-- Content host + panels
---------------------------------------------------------------------
local function ensureNavRailPlate(screen)
  if screen.navRailPlate then return screen.navRailPlate end
  local parent = screen.container or screen.control
  if not parent then return nil end
  local plate = WM:CreateControl("DM2StatsMenuNavRailPlate", parent, CT_BACKDROP)
  plate:SetCenterColor(THEME.railR, THEME.railG, THEME.railB, THEME.railA)
  plate:SetEdgeColor(THEME.railEdgeR, THEME.railEdgeG, THEME.railEdgeB, THEME.railEdgeA)
  plate:SetInsets(2, 2, -2, -2)
  stampBackground(plate, 1)
  screen.navRailPlate = plate
  return plate
end

local function ensureContentHost(screen)
  if screen.contentHost and screen.contentPanels then
    return screen.contentHost, screen.contentPanels
  end
  local parent = screen.container or screen.control
  local host = screen.contentHost
  if not host then
    host = WM:CreateControl("DM2StatsMenuContentHost", parent, CT_CONTROL)
    host:SetHidden(false)
    stampForeground(host, 10)
    screen.contentHost = host
  end

  if not screen.contentPlate then
    local plate = WM:CreateControl("DM2StatsMenuContentPlate", host, CT_BACKDROP)
    plate:SetCenterColor(THEME.plateR, THEME.plateG, THEME.plateB, THEME.plateA)
    plate:SetEdgeColor(THEME.plateEdgeR, THEME.plateEdgeG, THEME.plateEdgeB, THEME.plateEdgeA)
    plate:SetInsets(2, 2, -2, -2)
    local inset = CONTENT_PLATE_INSET
    plate:SetAnchor(TOPLEFT, host, TOPLEFT, inset, inset)
    plate:SetAnchor(BOTTOMRIGHT, host, BOTTOMRIGHT, -inset, -inset)
    stampBackground(plate, 0)
    screen.contentPlate = plate
  end

  if not screen.contentPanels then
    local panels = {
      overview      = WM:CreateControl("DM2StatsMenuOverviewPanel", host, CT_CONTROL),
      dashboard     = WM:CreateControl("DM2StatsMenuDashboardPanel", host, CT_CONTROL),
      damage        = WM:CreateControl("DM2StatsMenuDamagePanel", host, CT_CONTROL),
      weave         = WM:CreateControl("DM2StatsMenuWeavePanel", host, CT_CONTROL),
      buffs         = WM:CreateControl("DM2StatsMenuBuffsPanel", host, CT_CONTROL),
      gear          = WM:CreateControl("DM2StatsMenuGearPanel", host, CT_CONTROL),
      procs         = WM:CreateControl("DM2StatsMenuProcsPanel", host, CT_CONTROL),
      rotation      = WM:CreateControl("DM2StatsMenuRotationPanel", host, CT_CONTROL),
      insightsDps   = WM:CreateControl("DM2StatsMenuInsightsDpsPanel", host, CT_CONTROL),
      insightsBuild = WM:CreateControl("DM2StatsMenuInsightsBuildPanel", host, CT_CONTROL),
      history       = WM:CreateControl("DM2StatsMenuHistoryPanel", host, CT_CONTROL),
    }
    for _, panel in pairs(panels) do
      panel:SetHidden(true)
      stampForeground(panel, 50)
    end
    screen.contentPanels = panels
  else
    -- Hot-upgrade older shells missing split Insights panels
    if not screen.contentPanels.insightsDps then
      screen.contentPanels.insightsDps = screen.contentPanels.insights
        or WM:CreateControl("DM2StatsMenuInsightsDpsPanel", host, CT_CONTROL)
      screen.contentPanels.insightsDps:SetHidden(true)
      stampForeground(screen.contentPanels.insightsDps, 50)
    end
    if not screen.contentPanels.insightsBuild then
      screen.contentPanels.insightsBuild = WM:CreateControl("DM2StatsMenuInsightsBuildPanel", host, CT_CONTROL)
      screen.contentPanels.insightsBuild:SetHidden(true)
      stampForeground(screen.contentPanels.insightsBuild, 50)
    end
  end

  return host, screen.contentPanels
end

local function layoutNavList(screen)
  local rect = resolveShellRects()
  local parent = screen.container or screen.control
  if not parent then return rect end
  local rail = ensureNavRailPlate(screen)
  if rail then
    forceControlRect(rail, parent, rect.navLeft, rect.navTop, rect.navW, rect.navH)
    stampBackground(rail, 1)
  end
  local listCtrl = getNavListControl(screen)
  if listCtrl then
    forceControlRect(listCtrl, parent, rect.navLeft, rect.navTop, rect.navW, rect.navH)
    stampForeground(listCtrl, 80)
  end
  local listObj = screen.navList
  if listObj and listObj.list and listObj.list ~= listCtrl then
    pcall(function()
      listObj.list:SetWidth(rect.navW)
      if type(listObj.list.SetHeight) == "function" then listObj.list:SetHeight(rect.navH) end
    end)
  end
  return rect
end

local function layoutContentHost(screen)
  local host = screen.contentHost
  if not host then
    local rect = resolveShellRects()
    local shrink = (CONTENT_PLATE_INSET + CONTENT_INNER_INSET) * 2
    return math.max(320, rect.contentW - shrink), math.max(280, rect.contentH - shrink)
  end
  local rect = resolveShellRects()
  local parent = screen.container or screen.control
  forceControlRect(host, parent, rect.contentLeft, rect.contentTop, rect.contentW, rect.contentH)
  stampForeground(host, 10)
  local plateInset = CONTENT_PLATE_INSET
  if screen.contentPlate then
    screen.contentPlate:ClearAnchors()
    screen.contentPlate:SetAnchor(TOPLEFT, host, TOPLEFT, plateInset, plateInset)
    screen.contentPlate:SetAnchor(BOTTOMRIGHT, host, BOTTOMRIGHT, -plateInset, -plateInset)
    screen.contentPlate:SetHidden(false)
    stampBackground(screen.contentPlate, 0)
    screen.contentPlate:SetCenterColor(THEME.plateR, THEME.plateG, THEME.plateB, THEME.plateA)
    screen.contentPlate:SetEdgeColor(THEME.plateEdgeR, THEME.plateEdgeG, THEME.plateEdgeB, THEME.plateEdgeA)
  end
  -- Content panels sit *inside* the plate so they never bleed over the 70% edge fade.
  local panelInset = plateInset + CONTENT_INNER_INSET
  local panels = screen.contentPanels or {}
  for _, panel in pairs(panels) do
    if panel then
      panel:ClearAnchors()
      panel:SetAnchor(TOPLEFT, host, TOPLEFT, panelInset, panelInset)
      panel:SetAnchor(BOTTOMRIGHT, host, BOTTOMRIGHT, -panelInset, -panelInset)
      stampForeground(panel, 50)
    end
  end
  local shrink = panelInset * 2
  return math.max(320, rect.contentW - shrink), math.max(280, rect.contentH - shrink)
end

local function applyDualPaneLayout(screen)
  if not screen then return end
  ensureContentHost(screen)
  layoutNavList(screen)
  layoutContentHost(screen)
end

local function showContentTab(screen, tabIndex)
  applyDualPaneLayout(screen)
  local panels = screen.contentPanels or {}
  local active = TAB_KEY[tabIndex] or "overview"
  for key, panel in pairs(panels) do
    if panel then panel:SetHidden(key ~= active) end
  end
  return active
end

---------------------------------------------------------------------
-- Overview = overlay Summary page (dense; lazy-created once)
-- Structure: header → KPI grid → rotation + burst/drop → sparkline →
--            set contribution → top damage skills
---------------------------------------------------------------------
local OV_KPI_COLS = 5
local OV_KPI_KEYS = {
  { key = "avg", label = "Fight Avg DPS" },
  { key = "peak", label = "Peak 2s DPS" },
  { key = "total", label = "Fight Total" },
  { key = "dur", label = "Fight Duration" },
  { key = "crit", label = "Crit Rate" },
  { key = "maxhit", label = "Max Hit" },
  { key = "split", label = "Direct vs DoT" },
  { key = "events", label = "Damage Events" },
  { key = "epm", label = "Dmg Events / Min" },
  { key = "weave", label = "Weave Success" },
  { key = "avglag", label = "Avg LA Gap" },
  { key = "setpct", label = "Set Proc Share" },
  { key = "heal", label = "Total Healing" },
  { key = "hps", label = "Effective HPS" },
  { key = "overheal", label = "Overheal %" },
}
local OV_SPARK_BARS = 20
local OV_TOP_SKILLS = 5
local OV_SET_ROWS = 3

local function createOverviewUI(screen)
  if screen.overviewUI then return screen.overviewUI end
  ensureContentHost(screen)
  local panel = screen.contentPanels and screen.contentPanels.overview
  if not panel then return nil end

  local ui = {
    panel = panel,
    kpi = {},
    rotLines = {},
    spikes = {},
    dips = {},
    setRows = {},
    skillRows = {},
    sparkBars = {},
  }

  -- Root fills the content plate; sections stack top→bottom.
  ui.root = WM:CreateControl("DM2StatsMenuOvRoot", panel, CT_CONTROL)
  ui.root:SetAnchor(TOPLEFT, panel, TOPLEFT, CONTENT_PAD, 6)
  stampForeground(ui.root, 55)

  ui.fightLine = makeDashLabel(ui.root, "DM2StatsMenuOvFight", 20, 0.95, 0.92, 0.86, 1)
  ui.fightLine:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, 0)

  ui.metaLine = makeDashLabel(ui.root, "DM2StatsMenuOvMeta", 14, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.metaLine:SetAnchor(TOPLEFT, ui.fightLine, BOTTOMLEFT, 0, 2)

  -- KPI panel
  ui.kpiPanel = WM:CreateControl("DM2StatsMenuOvKpiPanel", ui.root, CT_CONTROL)
  ui.kpiPanel:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, 48)
  local kpiBg = makeSectionFrame(ui.kpiPanel, "DM2StatsMenuOvKpiBG", true)
  kpiBg:SetAnchorFill(ui.kpiPanel)
  for i, def in ipairs(OV_KPI_KEYS) do
    local block = WM:CreateControl("DM2StatsMenuOvKpi_" .. def.key, ui.kpiPanel, CT_CONTROL)
    local bg = makeSectionFrame(block, "DM2StatsMenuOvKpiBG_" .. def.key, false)
    bg:SetAnchorFill(block)
    local value = makeDashLabel(block, "DM2StatsMenuOvKpiVal_" .. def.key, 16, THEME.textR, THEME.textG, THEME.textB, 1)
    value:SetAnchor(TOPLEFT, block, TOPLEFT, 8, 4)
    local label = makeDashLabel(block, "DM2StatsMenuOvKpiLab_" .. def.key, 12, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
    label:SetAnchor(TOPLEFT, value, BOTTOMLEFT, 0, 0)
    label:SetText(def.label)
    ui.kpi[def.key] = { block = block, value = value, label = label, bg = bg }
  end

  -- Mid: Rotation Health | Burst / Drop
  ui.rotPanel = WM:CreateControl("DM2StatsMenuOvRotPanel", ui.root, CT_CONTROL)
  local rotBg = makeSectionFrame(ui.rotPanel, "DM2StatsMenuOvRotBG", true)
  rotBg:SetAnchorFill(ui.rotPanel)
  ui.rotTitle = makeDashLabel(ui.rotPanel, "DM2StatsMenuOvRotTitle", 14, 0.58, 0.86, 1.0, 1)
  ui.rotTitle:SetAnchor(TOPLEFT, ui.rotPanel, TOPLEFT, 10, 6)
  ui.rotTitle:SetText("Rotation Health")
  ui.rotHelp = makeDashLabel(ui.rotPanel, "DM2StatsMenuOvRotHelp", 12, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.rotHelp:SetAnchor(TOPLEFT, ui.rotTitle, BOTTOMLEFT, 0, 1)
  ui.rotHelp:SetText("Light attack timing, misses, and rhythm health")
  for i = 1, 4 do
    local l1 = makeDashLabel(ui.rotPanel, "DM2StatsMenuOvRotL" .. i, 13, THEME.textR, THEME.textG, THEME.textB, 1)
    local l2 = makeDashLabel(ui.rotPanel, "DM2StatsMenuOvRotR" .. i, 13, THEME.textR, THEME.textG, THEME.textB, 1)
    ui.rotLines[i] = { l1, l2 }
  end

  ui.burstPanel = WM:CreateControl("DM2StatsMenuOvBurstPanel", ui.root, CT_CONTROL)
  local burstBg = makeSectionFrame(ui.burstPanel, "DM2StatsMenuOvBurstBG", true)
  burstBg:SetAnchorFill(ui.burstPanel)
  ui.burstTitle = makeDashLabel(ui.burstPanel, "DM2StatsMenuOvBurstTitle", 14, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.burstTitle:SetAnchor(TOPLEFT, ui.burstPanel, TOPLEFT, 10, 6)
  ui.burstTitle:SetText("Burst / Drop Windows")
  ui.spikeHead = makeDashLabel(ui.burstPanel, "DM2StatsMenuOvSpikeHead", 12, 0.72, 0.95, 1.0, 1)
  ui.spikeHead:SetText("Bursts")
  ui.dipHead = makeDashLabel(ui.burstPanel, "DM2StatsMenuOvDipHead", 12, 1.0, 0.72, 0.55, 1)
  ui.dipHead:SetText("Drops")
  for i = 1, 3 do
    ui.spikes[i] = makeDashLabel(ui.burstPanel, "DM2StatsMenuOvSpike" .. i, 13, THEME.textR, THEME.textG, THEME.textB, 1)
    ui.dips[i] = makeDashLabel(ui.burstPanel, "DM2StatsMenuOvDip" .. i, 13, THEME.textR, THEME.textG, THEME.textB, 1)
  end

  -- Sparkline
  ui.sparkPanel = WM:CreateControl("DM2StatsMenuOvSparkPanel", ui.root, CT_CONTROL)
  local sparkBg = makeSectionFrame(ui.sparkPanel, "DM2StatsMenuOvSparkBG", true)
  sparkBg:SetAnchorFill(ui.sparkPanel)
  ui.sparkTitle = makeDashLabel(ui.sparkPanel, "DM2StatsMenuOvSparkTitle", 13, 0.72, 0.95, 1.0, 1)
  ui.sparkTitle:SetAnchor(TOPLEFT, ui.sparkPanel, TOPLEFT, 10, 4)
  ui.sparkTitle:SetText("DPS Over Time")
  ui.sparkWrap = WM:CreateControl("DM2StatsMenuOvSparkWrap", ui.sparkPanel, CT_CONTROL)
  ui.sparkWrap:SetAnchor(TOPLEFT, ui.sparkPanel, TOPLEFT, 10, 22)
  for i = 1, OV_SPARK_BARS do
    local bar = WM:CreateControl("DM2StatsMenuOvSparkBar" .. i, ui.sparkWrap, CT_BACKDROP)
    bar:SetCenterColor(0.3, 0.7, 1.0, 0.9)
    bar:SetEdgeColor(0, 0, 0, 0)
    bar:SetHidden(true)
    stampForeground(bar, 95)
    ui.sparkBars[i] = bar
  end

  -- Set contribution
  ui.setPanel = WM:CreateControl("DM2StatsMenuOvSetPanel", ui.root, CT_CONTROL)
  local setBg = makeSectionFrame(ui.setPanel, "DM2StatsMenuOvSetBG", true)
  setBg:SetAnchorFill(ui.setPanel)
  ui.setTitle = makeDashLabel(ui.setPanel, "DM2StatsMenuOvSetTitle", 14, 1.0, 0.90, 0.50, 1)
  ui.setTitle:SetAnchor(TOPLEFT, ui.setPanel, TOPLEFT, 10, 6)
  ui.setTitle:SetText("Set Contribution")
  for i = 1, OV_SET_ROWS do
    local row = WM:CreateControl("DM2StatsMenuOvSetRow" .. i, ui.setPanel, CT_CONTROL)
    local shareBg = WM:CreateControl("DM2StatsMenuOvSetShareBg" .. i, row, CT_BACKDROP)
    shareBg:SetCenterColor(0.12, 0.12, 0.14, 0.55)
    shareBg:SetEdgeColor(0, 0, 0, 0)
    shareBg:SetAnchor(BOTTOMLEFT, row, BOTTOMLEFT, 0, 0)
    shareBg:SetDimensions(200, 5)
    local shareFg = WM:CreateControl("DM2StatsMenuOvSetShareFg" .. i, shareBg, CT_BACKDROP)
    shareFg:SetCenterColor(0.92, 0.78, 0.40, 0.9)
    shareFg:SetEdgeColor(0, 0, 0, 0)
    shareFg:SetAnchor(TOPLEFT, shareBg, TOPLEFT, 0, 0)
    shareFg:SetDimensions(2, 5)
    local line = makeDashLabel(row, "DM2StatsMenuOvSetLine" .. i, 13, THEME.textR, THEME.textG, THEME.textB, 1)
    line:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 0)
    ui.setRows[i] = { row = row, line = line, shareBg = shareBg, shareFg = shareFg }
  end

  -- Top damage skills
  ui.skillsPanel = WM:CreateControl("DM2StatsMenuOvSkillsPanel", ui.root, CT_CONTROL)
  local skBg = makeSectionFrame(ui.skillsPanel, "DM2StatsMenuOvSkillsBG", true)
  skBg:SetAnchorFill(ui.skillsPanel)
  ui.skillsTitle = makeDashLabel(ui.skillsPanel, "DM2StatsMenuOvSkillsTitle", 14, 0.86, 0.94, 1.0, 1)
  ui.skillsTitle:SetAnchor(TOPLEFT, ui.skillsPanel, TOPLEFT, 10, 6)
  ui.skillsTitle:SetText("Top Damage Skills")
  -- Legend on the same title row (right) so it never drops into skill rows.
  ui.skillsLegend = makeDashLabel(ui.skillsPanel, "DM2StatsMenuOvSkillsLegend", 12, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.skillsLegend:SetAnchor(TOPRIGHT, ui.skillsPanel, TOPRIGHT, -12, 8)
  ui.skillsLegend:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  ui.skillsLegend:SetText("|c88DDAAF|r Front  |c88AADDB|r Back  |cFAC538U|r Ult  |cF29E38S|r Set  |cC761F2E|r Effect")
  for i = 1, OV_TOP_SKILLS do
    local row = WM:CreateControl("DM2StatsMenuOvSkillRow" .. i, ui.skillsPanel, CT_CONTROL)
    local chip = makeDashLabel(row, "DM2StatsMenuOvSkillChip" .. i, 12, THEME.frontR, THEME.frontG, THEME.frontB, 1)
    chip:SetAnchor(LEFT, row, LEFT, 0, 0)
    chip:SetDimensions(14, 16)
    local icon = WM:CreateControl("DM2StatsMenuOvSkillIcon" .. i, row, CT_TEXTURE)
    icon:SetDimensions(26, 26)
    icon:SetAnchor(LEFT, row, LEFT, 16, 0)
    stampForeground(icon, 110)
    local name = makeDashLabel(row, "DM2StatsMenuOvSkillName" .. i, 14, THEME.textR, THEME.textG, THEME.textB, 1)
    name:SetAnchor(TOPLEFT, row, TOPLEFT, 48, 0)
    local sub = makeDashLabel(row, "DM2StatsMenuOvSkillSub" .. i, 12, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
    sub:SetAnchor(TOPLEFT, name, BOTTOMLEFT, 0, 0)
    local shareBg = WM:CreateControl("DM2StatsMenuOvSkillShareBg" .. i, row, CT_BACKDROP)
    shareBg:SetCenterColor(0.12, 0.12, 0.14, 0.55)
    shareBg:SetEdgeColor(0, 0, 0, 0)
    shareBg:SetAnchor(BOTTOMLEFT, row, BOTTOMLEFT, 48, 0)
    shareBg:SetDimensions(220, 5)
    local shareFg = WM:CreateControl("DM2StatsMenuOvSkillShareFg" .. i, shareBg, CT_BACKDROP)
    shareFg:SetCenterColor(0.55, 0.78, 0.42, 0.9)
    shareFg:SetEdgeColor(0, 0, 0, 0)
    shareFg:SetAnchor(TOPLEFT, shareBg, TOPLEFT, 0, 0)
    shareFg:SetDimensions(2, 5)
    ui.skillRows[i] = {
      row = row, chip = chip, icon = icon, name = name, sub = sub,
      shareBg = shareBg, shareFg = shareFg,
    }
  end

  ui.empty = makeDashLabel(ui.root, "DM2StatsMenuOvEmpty", 16, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.empty:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, 48)
  ui.empty:SetHidden(true)

  screen.overviewUI = ui
  return ui
end

local function layoutOverviewUI(ui, hostW, hostH)
  if not ui or not ui.root then return end
  -- Content plate already includes pad; don't double-subtract so tiles get full width.
  local W = math.max(480, (hostW or 900) - 8)
  local H = math.max(420, (hostH or 700) - 8)
  ui.root:ClearAnchors()
  ui.root:SetAnchor(TOPLEFT, ui.panel, TOPLEFT, 8, 4)
  ui.root:SetDimensions(W, H)
  ui.fightLine:SetWidth(W - 4)
  ui.metaLine:SetWidth(W - 4)
  ui.empty:SetWidth(W - 4)

  -- Fixed section heights that fit ~1080p plate without overlapping.
  local headerH = 44
  local kpiH = 148
  local midH = 150
  local sparkH = 58
  local setH = 78
  local used = headerH + kpiH + 6 + midH + 6 + sparkH + 6 + setH + 6
  local skillsH = math.max(140, H - used - 4)
  if skillsH > 200 then skillsH = 200 end

  ui.kpiPanel:ClearAnchors()
  ui.kpiPanel:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, headerH)
  ui.kpiPanel:SetDimensions(W, kpiH)

  local gapX, gapY = 6, 6
  local cols = OV_KPI_COLS
  local pad = 8
  local kpiInnerW = W - pad * 2
  local kpiW = math.floor((kpiInnerW - gapX * (cols - 1)) / cols)
  local rows = 3
  local kpiBlockH = math.floor((kpiH - pad * 2 - gapY * (rows - 1)) / rows)
  if kpiBlockH < 38 then kpiBlockH = 38 end
  if kpiBlockH > 44 then kpiBlockH = 44 end
  for i, def in ipairs(OV_KPI_KEYS) do
    local cell = ui.kpi[def.key]
    local block = cell and cell.block
    if block then
      local col = (i - 1) % cols
      local row = math.floor((i - 1) / cols)
      block:ClearAnchors()
      block:SetDimensions(kpiW, kpiBlockH)
      block:SetAnchor(TOPLEFT, ui.kpiPanel, TOPLEFT, pad + col * (kpiW + gapX), pad + row * (kpiBlockH + gapY))
      if cell.value then
        cell.value:ClearAnchors()
        cell.value:SetAnchor(TOPLEFT, block, TOPLEFT, 8, 4)
        cell.value:SetWidth(kpiW - 14)
        cell.value:SetMaxLineCount(1)
      end
      if cell.label then
        cell.label:ClearAnchors()
        cell.label:SetAnchor(BOTTOMLEFT, block, BOTTOMLEFT, 8, -4)
        cell.label:SetWidth(kpiW - 14)
        cell.label:SetMaxLineCount(1)
      end
    end
  end

  local midY = headerH + kpiH + 6
  local leftW = math.floor(W * 0.34)
  if leftW < 240 then leftW = 240 end
  if leftW > 320 then leftW = 320 end
  local rightW = W - leftW - 8

  ui.rotPanel:ClearAnchors()
  ui.rotPanel:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, midY)
  ui.rotPanel:SetDimensions(leftW, midH)
  ui.rotTitle:SetWidth(leftW - 20)
  ui.rotHelp:SetWidth(leftW - 20)
  -- Single column of rotation lines (avoids cramped dual-col wrap).
  for i = 1, 4 do
    local pair = ui.rotLines[i]
    if pair then
      pair[1]:ClearAnchors()
      pair[1]:SetAnchor(TOPLEFT, ui.rotPanel, TOPLEFT, 10, 42 + (i - 1) * 24)
      pair[1]:SetWidth(leftW - 20)
      pair[1]:SetMaxLineCount(1)
      pair[2]:ClearAnchors()
      pair[2]:SetAnchor(TOPRIGHT, ui.rotPanel, TOPRIGHT, -10, 42 + (i - 1) * 24)
      pair[2]:SetWidth(math.floor((leftW - 24) / 2))
      pair[2]:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
      pair[2]:SetMaxLineCount(1)
    end
  end

  ui.burstPanel:ClearAnchors()
  ui.burstPanel:SetAnchor(TOPLEFT, ui.root, TOPLEFT, leftW + 8, midY)
  ui.burstPanel:SetDimensions(rightW, midH)
  ui.burstTitle:SetWidth(rightW - 20)
  -- Side-by-side Bursts | Drops (matches overlay intent; no vertical collision).
  local colW = math.floor((rightW - 28) / 2)
  ui.spikeHead:ClearAnchors()
  ui.spikeHead:SetAnchor(TOPLEFT, ui.burstPanel, TOPLEFT, 10, 28)
  ui.spikeHead:SetWidth(colW)
  ui.dipHead:ClearAnchors()
  ui.dipHead:SetAnchor(TOPLEFT, ui.burstPanel, TOPLEFT, 14 + colW, 28)
  ui.dipHead:SetWidth(colW)
  for i = 1, 3 do
    ui.spikes[i]:ClearAnchors()
    ui.spikes[i]:SetAnchor(TOPLEFT, ui.burstPanel, TOPLEFT, 10, 48 + (i - 1) * 28)
    ui.spikes[i]:SetWidth(colW)
    ui.spikes[i]:SetMaxLineCount(1)
    ui.dips[i]:ClearAnchors()
    ui.dips[i]:SetAnchor(TOPLEFT, ui.burstPanel, TOPLEFT, 14 + colW, 48 + (i - 1) * 28)
    ui.dips[i]:SetWidth(colW)
    ui.dips[i]:SetMaxLineCount(1)
  end

  local sparkY = midY + midH + 6
  ui.sparkPanel:ClearAnchors()
  ui.sparkPanel:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, sparkY)
  ui.sparkPanel:SetDimensions(W, sparkH)
  ui.sparkTitle:SetWidth(W - 20)
  ui.sparkWrap:ClearAnchors()
  ui.sparkWrap:SetAnchor(TOPLEFT, ui.sparkPanel, TOPLEFT, 10, 22)
  ui.sparkWrap:SetDimensions(W - 20, sparkH - 28)

  local setY = sparkY + sparkH + 6
  ui.setPanel:ClearAnchors()
  ui.setPanel:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, setY)
  ui.setPanel:SetDimensions(W, setH)
  ui.setTitle:SetWidth(W - 20)
  local setLineW = math.min(560, math.max(280, math.floor((W - 40) * 0.70)))
  local setBarW = math.min(160, math.max(80, W - 40 - setLineW - 20))
  for i = 1, OV_SET_ROWS do
    local r = ui.setRows[i]
    if r and r.row then
      r.row:ClearAnchors()
      r.row:SetAnchor(TOPLEFT, ui.setPanel, TOPLEFT, 10, 26 + (i - 1) * 16)
      r.row:SetDimensions(W - 20, 15)
      if r.line then
        r.line:ClearAnchors()
        r.line:SetAnchor(TOPLEFT, r.row, TOPLEFT, 0, 0)
        r.line:SetWidth(setLineW)
        r.line:SetMaxLineCount(1)
      end
      if r.shareBg then
        r.shareBg:ClearAnchors()
        r.shareBg:SetAnchor(TOPLEFT, r.row, TOPLEFT, setLineW + 12, 5)
        r.shareBg:SetDimensions(setBarW, 5)
      end
    end
  end

  local skillsY = setY + setH + 6
  ui.skillsPanel:ClearAnchors()
  ui.skillsPanel:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, skillsY)
  ui.skillsPanel:SetDimensions(W, skillsH)
  ui.skillsTitle:SetWidth(math.min(280, math.floor(W * 0.40)))
  ui.skillsLegend:SetWidth(math.min(420, math.floor(W * 0.52)))
  local rowH = math.floor((skillsH - 28) / OV_TOP_SKILLS)
  if rowH < 30 then rowH = 30 end
  if rowH > 34 then rowH = 34 end
  local skNameW = math.min(280, math.max(180, math.floor((W - 40) * 0.32)))
  local skSubW = math.min(420, math.max(200, math.floor((W - 40) * 0.40)))
  local skBarW = math.min(180, math.max(100, math.floor((W - 40) * 0.18)))
  for i = 1, OV_TOP_SKILLS do
    local r = ui.skillRows[i]
    if r and r.row then
      r.row:ClearAnchors()
      r.row:SetAnchor(TOPLEFT, ui.skillsPanel, TOPLEFT, 10, 28 + (i - 1) * rowH)
      r.row:SetDimensions(W - 20, rowH - 2)
      if r.name then
        r.name:ClearAnchors()
        r.name:SetAnchor(TOPLEFT, r.row, TOPLEFT, 48, 0)
        r.name:SetWidth(skNameW)
        r.name:SetMaxLineCount(1)
      end
      if r.sub then
        r.sub:ClearAnchors()
        r.sub:SetAnchor(TOPLEFT, r.row, TOPLEFT, 48 + skNameW + 8, 2)
        r.sub:SetWidth(skSubW)
        r.sub:SetMaxLineCount(1)
      end
      if r.shareBg then
        r.shareBg:ClearAnchors()
        r.shareBg:SetAnchor(TOPLEFT, r.row, TOPLEFT, 48 + skNameW + skSubW + 16, math.floor((rowH - 8) / 2))
        r.shareBg:SetDimensions(skBarW, 6)
      end
    end
  end
end

local function setOverviewBodyHidden(ui, hidden)
  if not ui then return end
  if ui.kpiPanel then ui.kpiPanel:SetHidden(hidden) end
  if ui.rotPanel then ui.rotPanel:SetHidden(hidden) end
  if ui.burstPanel then ui.burstPanel:SetHidden(hidden) end
  if ui.sparkPanel then ui.sparkPanel:SetHidden(hidden) end
  if ui.setPanel then ui.setPanel:SetHidden(hidden) end
  if ui.skillsPanel then ui.skillsPanel:SetHidden(hidden) end
end

local function refreshOverviewUI(screen, session)
  local ui = createOverviewUI(screen)
  if not ui then return end
  local hostW, hostH = layoutContentHost(screen)
  layoutOverviewUI(ui, hostW, hostH)

  if not session then
    ui.fightLine:SetText("No fight selected")
    ui.metaLine:SetText("Complete a parse, then open this menu again")
    ui.empty:SetText("History is empty — run a parse, then reopen.")
    ui.empty:SetHidden(false)
    setOverviewBodyHidden(ui, true)
    return
  end

  ui.empty:SetHidden(true)
  setOverviewBodyHidden(ui, false)

  local model = buildSummaryModel(session)
  if not model then return end

  ui.fightLine:SetText(model.target or "?")
  local meta = model.meta or ""
  local contrib = buildDamageContribution(session)
  if contrib and contrib.parts then
    local bits = {}
    for _, p in ipairs(contrib.parts) do
      if (p.pct or 0) >= 0.03 then
        bits[#bits + 1] = string.format("%s %s", p.label, p.pctTxt)
      end
    end
    if #bits > 0 then
      meta = meta .. "  ·  |cC0A060Dmg:|r " .. table.concat(bits, " · ")
    end
  end
  -- Full meta width; avoid early truncate of set list + dmg mix
  if ui.metaLine then
    ui.metaLine:SetText(meta)
    if ui.metaLine.SetMaxLineCount then ui.metaLine:SetMaxLineCount(2) end
  end

  for _, def in ipairs(OV_KPI_KEYS) do
    local cell = ui.kpi[def.key]
    local data = nil
    for _, k in ipairs(model.kpis or {}) do
      if k.key == def.key then data = k break end
    end
    if cell and cell.value then
      cell.value:SetText(data and data.value or "-")
    end
  end

  for i = 1, 4 do
    local pair = ui.rotLines[i]
    local rot = model.rot and model.rot[i]
    if pair then
      pair[1]:SetText(rot and rot[1] or "")
      pair[2]:SetText(rot and rot[2] or "")
    end
  end

  for i = 1, 3 do
    if ui.spikes[i] then ui.spikes[i]:SetText((model.spikes and model.spikes[i]) or "") end
    if ui.dips[i] then ui.dips[i]:SetText((model.dips and model.dips[i]) or "") end
  end

  local sparkVals = {}
  for _, b in ipairs(model.spark or {}) do
    sparkVals[#sparkVals + 1] = tonumber(b.dmg) or 0
  end
  local sparkW = ui.sparkWrap and ui.sparkWrap:GetWidth() or 400
  if sparkW < 50 then sparkW = math.max(200, (hostW or 600) - 40) end
  layoutSparkBars(ui.sparkBars, ui.sparkWrap, sparkVals, sparkW, 28, OV_SPARK_BARS)

  for i = 1, OV_SET_ROWS do
    local r = ui.setRows[i]
    local s = model.sets and model.sets[i]
    if r then
      if s then
        r.row:SetHidden(false)
        r.line:SetText(s.line or "")
        local share = tonumber(s.share) or 0
        local bgW = r.shareBg:GetWidth() or 200
        if bgW < 10 then bgW = 200 end
        r.shareFg:SetDimensions(math.max(2, math.floor(bgW * math.min(1, share))), 4)
      else
        r.row:SetHidden(i ~= 1)
        if i == 1 then
          r.row:SetHidden(false)
          r.line:SetText("No set/proc contribution recorded.")
          r.shareFg:SetDimensions(2, 4)
        end
      end
    end
  end

  for i = 1, OV_TOP_SKILLS do
    local r = ui.skillRows[i]
    local sk = model.topSkills and model.topSkills[i]
    if r then
      if sk then
        r.row:SetHidden(false)
        r.name:SetText(sk.name or "?")
        r.sub:SetText(sk.sub or "")
        local chip = sk.sourceChip or barChipLabel(sk.bar)
        if chip == "" and sk.source == "Effect" then chip = "E" end
        if chip == "" and sk.source == "Set proc" then chip = "S" end
        r.chip:SetText(chip)
        local cr, cg, cb, ca = sourceChipColor(chip, sk.bar)
        r.chip:SetColor(cr, cg, cb, ca)
        r.chip:SetHidden(chip == "")
        if sk.icon then
          r.icon:SetTexture(sk.icon)
          r.icon:SetHidden(false)
          r.icon:SetColor(1, 1, 1, 1)
        else
          r.icon:SetHidden(true)
        end
        -- Relative to #1 top skill for clearer impact bars
        local rel = tonumber(sk.relShare) or tonumber(sk.share) or 0
        local bgW = r.shareBg:GetWidth() or 220
        if bgW < 10 then bgW = 220 end
        r.shareFg:SetDimensions(math.max(2, math.floor(bgW * math.min(1, rel))), 4)
      else
        r.row:SetHidden(true)
      end
    end
  end
end

---------------------------------------------------------------------
-- Damage: dual panel — Skills (F/B/LA/HA/U) | Effects (E/S)
---------------------------------------------------------------------
local DMG_SKILL_ROWS = 22
local DMG_FX_ROWS = 22
local DMG_MAX_ROWS = 80 -- fetch budget before split into Skills / Effects panels
local DMG_ROW_H = 26

local function makeDamageRow(parent, pfx, i, compact)
  local row = WM:CreateControl(pfx .. "Row" .. i, parent, CT_CONTROL)
  local chip = makeDashLabel(row, pfx .. "Chip" .. i, 11, THEME.frontR, THEME.frontG, THEME.frontB, 1)
  chip:SetDimensions(18, 16)
  local icon = WM:CreateControl(pfx .. "Icon" .. i, row, CT_TEXTURE)
  icon:SetDimensions(compact and 20 or 24, compact and 20 or 24)
  stampForeground(icon, 110)
  local name = makeDashLabel(row, pfx .. "Name" .. i, compact and 12 or 13, THEME.textR, THEME.textG, THEME.textB, 1)
  local amount = makeDashLabel(row, pfx .. "Amt" .. i, 12, THEME.textR, THEME.textG, THEME.textB, 1)
  amount:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  local hits = makeDashLabel(row, pfx .. "Hits" .. i, 12, THEME.textR, THEME.textG, THEME.textB, 1)
  hits:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  local share = makeDashLabel(row, pfx .. "Share" .. i, 12, THEME.textR, THEME.textG, THEME.textB, 1)
  share:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  local crit = makeDashLabel(row, pfx .. "Crit" .. i, 12, THEME.textR, THEME.textG, THEME.textB, 1)
  crit:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  local kind = makeDashLabel(row, pfx .. "Type" .. i, 11, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  kind:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
  local dps = makeDashLabel(row, pfx .. "Dps" .. i, 12, THEME.textR, THEME.textG, THEME.textB, 1)
  dps:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  return {
    row = row, chip = chip, icon = icon, name = name,
    amount = amount, hits = hits, share = share, crit = crit, kind = kind, dps = dps,
    compact = compact and true or false,
  }
end

local function createDamageUI(screen)
  if screen.damageUI and not screen.damageUI._v31714 then screen.damageUI = nil end
  if screen.damageUI then return screen.damageUI end
  ensureContentHost(screen)
  local panel = screen.contentPanels and screen.contentPanels.damage
  if not panel then return nil end

  local ui = { panel = panel, skillRows = {}, fxRows = {}, _v31714 = true }

  ui.root = WM:CreateControl("DM2StatsMenuDmgRootV3", panel, CT_CONTROL)
  ui.root:SetAnchor(TOPLEFT, panel, TOPLEFT, 6, 2)
  stampForeground(ui.root, 55)

  ui.title = makeDashLabel(ui.root, "DM2StatsMenuDmgTitleV3", 16, 0.90, 0.96, 1.0, 1)
  ui.title:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, 0)
  ui.title:SetText("DAMAGE BREAKDOWN")
  ui.meta = makeDashLabel(ui.root, "DM2StatsMenuDmgMetaV3", 12, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.meta:SetAnchor(TOPLEFT, ui.title, BOTTOMLEFT, 0, 2)
  ui.legend = makeDashLabel(ui.root, "DM2StatsMenuDmgLegendV3", 11, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.legend:SetAnchor(TOPLEFT, ui.meta, BOTTOMLEFT, 0, 1)
  ui.legend:SetText("|c88DDAAF|r Front  |c88AADDB|r Back  |cFAC538U|r Ult  |cF29E38S|r Set  |cC761F2E|r Effect  ·  Type = Direct/DoT · Mag/Phys · ST/AoE")

  -- Left: slotted skills / LA / HA / Ult
  ui.skillPanel = WM:CreateControl("DM2StatsMenuDmgSkillPanelV3", ui.root, CT_CONTROL)
  local sbg = makeSectionFrame(ui.skillPanel, "DM2StatsMenuDmgSkillBGV3", true)
  sbg:SetAnchorFill(ui.skillPanel)
  ui.skillTitle = makeDashLabel(ui.skillPanel, "DM2StatsMenuDmgSkillTitleV3", 13, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.skillTitle:SetText("SKILLS  ·  F / B / LA / HA / ULT")
  ui.skillHdrName = makeDashLabel(ui.skillPanel, "DM2StatsMenuDmgSkillHdrN", 11, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.skillHdrName:SetText("Skill")
  ui.skillHdrAmt = makeDashLabel(ui.skillPanel, "DM2StatsMenuDmgSkillHdrA", 11, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.skillHdrAmt:SetText("Amount")
  ui.skillHdrAmt:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  ui.skillHdrHits = makeDashLabel(ui.skillPanel, "DM2StatsMenuDmgSkillHdrH", 11, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.skillHdrHits:SetText("Hits")
  ui.skillHdrHits:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  ui.skillHdrShare = makeDashLabel(ui.skillPanel, "DM2StatsMenuDmgSkillHdrS", 11, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.skillHdrShare:SetText("Share")
  ui.skillHdrShare:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  ui.skillHdrCrit = makeDashLabel(ui.skillPanel, "DM2StatsMenuDmgSkillHdrC", 11, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.skillHdrCrit:SetText("Crit")
  ui.skillHdrCrit:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  ui.skillHdrType = makeDashLabel(ui.skillPanel, "DM2StatsMenuDmgSkillHdrT", 11, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.skillHdrType:SetText("Type")
  ui.skillHdrDps = makeDashLabel(ui.skillPanel, "DM2StatsMenuDmgSkillHdrD", 11, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.skillHdrDps:SetText("DPS")
  ui.skillHdrDps:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  for i = 1, DMG_SKILL_ROWS do
    ui.skillRows[i] = makeDamageRow(ui.skillPanel, "DM2StatsMenuDmgSkV3", i, false)
  end

  -- Right: effects / set procs (more compressed)
  ui.fxPanel = WM:CreateControl("DM2StatsMenuDmgFxPanelV3", ui.root, CT_CONTROL)
  local fbg = makeSectionFrame(ui.fxPanel, "DM2StatsMenuDmgFxBGV3", true)
  fbg:SetAnchorFill(ui.fxPanel)
  ui.fxTitle = makeDashLabel(ui.fxPanel, "DM2StatsMenuDmgFxTitleV3", 13, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.fxTitle:SetText("EFFECTS  ·  E / S")
  ui.fxHdrName = makeDashLabel(ui.fxPanel, "DM2StatsMenuDmgFxHdrN", 11, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.fxHdrName:SetText("Effect")
  ui.fxHdrAmt = makeDashLabel(ui.fxPanel, "DM2StatsMenuDmgFxHdrA", 11, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.fxHdrAmt:SetText("Amount")
  ui.fxHdrAmt:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  ui.fxHdrShare = makeDashLabel(ui.fxPanel, "DM2StatsMenuDmgFxHdrS", 11, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.fxHdrShare:SetText("Share")
  ui.fxHdrShare:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  ui.fxHdrType = makeDashLabel(ui.fxPanel, "DM2StatsMenuDmgFxHdrT", 11, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.fxHdrType:SetText("Type")
  ui.fxHdrDps = makeDashLabel(ui.fxPanel, "DM2StatsMenuDmgFxHdrD", 11, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.fxHdrDps:SetText("DPS")
  ui.fxHdrDps:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  for i = 1, DMG_FX_ROWS do
    ui.fxRows[i] = makeDamageRow(ui.fxPanel, "DM2StatsMenuDmgFxV3", i, true)
  end

  ui.empty = makeDashLabel(ui.root, "DM2StatsMenuDmgEmptyV3", 15, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.empty:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, 60)
  ui.empty:SetHidden(true)

  screen.damageUI = ui
  return ui
end

local function layoutDamagePanelColumns(panel, hdrs, rows, maxRows, W, H, compact)
  local pad = 6
  -- nameX must clear chip (0-16) + icon (16 + 20/24) so text does not sit on icons
  local nameX = compact and 44 or 48
  local nameW = compact and math.max(90, math.floor(W * 0.28)) or math.max(110, math.floor(W * 0.30))
  local metricStart = nameX + nameW + 6
  local prefs
  if compact then
    prefs = { 70, 48, 92, 52 } -- amt share type dps
  else
    prefs = { 72, 40, 48, 42, 118, 52 } -- amt hits share crit type dps (wider Type for duplicate-id tags)
  end
  local gap = 4
  local prefSum = 0
  for _, w in ipairs(prefs) do prefSum = prefSum + w end
  prefSum = prefSum + gap * (#prefs - 1)
  local span = (W - pad) - metricStart
  local scale = span / math.max(1, prefSum)
  if scale > 1.25 then scale = 1.25 end
  if scale < 0.70 then scale = 0.70 end
  local widths, xs = {}, {}
  local x = metricStart
  for i, w in ipairs(prefs) do
    widths[i] = math.floor(w * scale)
    xs[i] = x
    x = x + widths[i] + gap
  end

  local function placeHdr(lbl, hx, hw)
    if not lbl then return end
    lbl:ClearAnchors()
    lbl:SetAnchor(TOPLEFT, panel, TOPLEFT, hx, 22)
    lbl:SetWidth(hw)
  end
  placeHdr(hdrs.name, nameX, nameW)
  if compact then
    placeHdr(hdrs.amt, xs[1], widths[1])
    placeHdr(hdrs.share, xs[2], widths[2])
    placeHdr(hdrs.kind, xs[3], widths[3])
    placeHdr(hdrs.dps, xs[4], widths[4])
  else
    placeHdr(hdrs.amt, xs[1], widths[1])
    placeHdr(hdrs.hits, xs[2], widths[2])
    placeHdr(hdrs.share, xs[3], widths[3])
    placeHdr(hdrs.crit, xs[4], widths[4])
    placeHdr(hdrs.kind, xs[5], widths[5])
    placeHdr(hdrs.dps, xs[6], widths[6])
  end

  local rowTop = 38
  local avail = H - rowTop - 4
  local rowH = math.floor(avail / maxRows)
  if rowH < 18 then rowH = 18 end
  if rowH > DMG_ROW_H then rowH = DMG_ROW_H end

  for i = 1, maxRows do
    local r = rows[i]
    if r and r.row then
      r.row:ClearAnchors()
      r.row:SetAnchor(TOPLEFT, panel, TOPLEFT, pad, rowTop + (i - 1) * rowH)
      r.row:SetDimensions(W - pad * 2, rowH - 1)
      r.chip:ClearAnchors()
      r.chip:SetAnchor(LEFT, r.row, LEFT, 0, 0)
      r.icon:ClearAnchors()
      r.icon:SetAnchor(LEFT, r.row, LEFT, 16, 0)
      r.name:ClearAnchors()
      r.name:SetAnchor(TOPLEFT, r.row, TOPLEFT, nameX - pad, 2)
      r.name:SetWidth(nameW)
      r.name:SetMaxLineCount(1)
      local function placeCell(lbl, cx, cw)
        if not lbl then return end
        lbl:ClearAnchors()
        lbl:SetAnchor(TOPLEFT, r.row, TOPLEFT, cx - pad, 3)
        lbl:SetWidth(cw)
        lbl:SetMaxLineCount(1)
      end
      if compact then
        placeCell(r.amount, xs[1], widths[1])
        placeCell(r.share, xs[2], widths[2])
        placeCell(r.kind, xs[3], widths[3])
        placeCell(r.dps, xs[4], widths[4])
        if r.hits then r.hits:SetHidden(true) end
        if r.crit then r.crit:SetHidden(true) end
      else
        placeCell(r.amount, xs[1], widths[1])
        placeCell(r.hits, xs[2], widths[2])
        placeCell(r.share, xs[3], widths[3])
        placeCell(r.crit, xs[4], widths[4])
        placeCell(r.kind, xs[5], widths[5])
        placeCell(r.dps, xs[6], widths[6])
        if r.hits then r.hits:SetHidden(false) end
        if r.crit then r.crit:SetHidden(false) end
      end
    end
  end
end

local function layoutDamageUI(ui, hostW, hostH)
  if not ui or not ui.root then return end
  local W = math.max(480, (hostW or 900) - 6)
  local H = math.max(400, (hostH or 700) - 6)
  ui.root:ClearAnchors()
  ui.root:SetAnchor(TOPLEFT, ui.panel, TOPLEFT, 6, 2)
  ui.root:SetDimensions(W, H)
  ui.title:SetWidth(W)
  ui.meta:SetWidth(W)
  if ui.meta.SetMaxLineCount then ui.meta:SetMaxLineCount(2) end
  ui.legend:SetWidth(W)
  ui.empty:SetWidth(W)

  -- Title + 2-line meta + legend need room so panel headers do not occlude them
  local bodyY, bodyH = 78, H - 82
  local gap = 6
  local leftW = math.floor((W - gap) * 0.58)
  local rightW = W - leftW - gap

  ui.skillPanel:ClearAnchors()
  ui.skillPanel:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, bodyY)
  ui.skillPanel:SetDimensions(leftW, bodyH)
  ui.fxPanel:ClearAnchors()
  ui.fxPanel:SetAnchor(TOPLEFT, ui.root, TOPLEFT, leftW + gap, bodyY)
  ui.fxPanel:SetDimensions(rightW, bodyH)

  ui.skillTitle:ClearAnchors()
  ui.skillTitle:SetAnchor(TOPLEFT, ui.skillPanel, TOPLEFT, 8, 4)
  ui.skillTitle:SetWidth(leftW - 16)
  ui.fxTitle:ClearAnchors()
  ui.fxTitle:SetAnchor(TOPLEFT, ui.fxPanel, TOPLEFT, 8, 4)
  ui.fxTitle:SetWidth(rightW - 16)

  layoutDamagePanelColumns(ui.skillPanel, {
    name = ui.skillHdrName, amt = ui.skillHdrAmt, hits = ui.skillHdrHits,
    share = ui.skillHdrShare, crit = ui.skillHdrCrit, kind = ui.skillHdrType, dps = ui.skillHdrDps,
  }, ui.skillRows, DMG_SKILL_ROWS, leftW, bodyH, false)

  layoutDamagePanelColumns(ui.fxPanel, {
    name = ui.fxHdrName, amt = ui.fxHdrAmt, share = ui.fxHdrShare,
    kind = ui.fxHdrType, dps = ui.fxHdrDps,
  }, ui.fxRows, DMG_FX_ROWS, rightW, bodyH, true)
end

local function fillDamageRow(r, sk, nameMax)
  if not r then return end
  if not sk then
    r.row:SetHidden(true)
    return
  end
  r.row:SetHidden(false)
  -- Names without long "id N" suffix on Damage (ids still on Build & Sets / Insights)
  r.name:SetText(displayName(sk.name or "?", nameMax or 36))
  r.amount:SetText(sk.amountTxt or "")
  if r.hits and not r.hits:IsHidden() then r.hits:SetText(sk.hitsTxt or "") end
  r.share:SetText(sk.shareTxt or "")
  if r.crit and not r.crit:IsHidden() then r.crit:SetText(sk.critTxt or "") end
  r.kind:SetText(sk.kindTxt or "")
  r.dps:SetText(sk.dpsTxt or "")
  local chip = sk.sourceChip or barChipLabel(sk.bar)
  if chip == "" and sk.source == "Effect" then chip = "E" end
  if chip == "" and sk.source == "Set proc" then chip = "S" end
  r.chip:SetText(chip)
  local cr, cg, cb, ca = sourceChipColor(chip, sk.bar)
  r.chip:SetColor(cr, cg, cb, ca)
  r.chip:SetHidden(chip == "")
  if sk.icon then
    r.icon:SetTexture(sk.icon)
    r.icon:SetHidden(false)
    r.icon:SetColor(1, 1, 1, 1)
  else
    r.icon:SetHidden(true)
  end
end

local function refreshDamageUI(screen, session)
  local ui = createDamageUI(screen)
  if not ui then return end
  local hostW, hostH = layoutContentHost(screen)
  layoutDamageUI(ui, hostW, hostH)

  if not session then
    ui.meta:SetText("No fight selected")
    ui.empty:SetText("History is empty.")
    ui.empty:SetHidden(false)
    ui.skillPanel:SetHidden(true)
    ui.fxPanel:SetHidden(true)
    return
  end
  ui.empty:SetHidden(true)
  ui.skillPanel:SetHidden(false)
  ui.fxPanel:SetHidden(false)

  local all = buildTopSkillRows(session, DMG_MAX_ROWS)
  local skills, effects = {}, {}
  for _, sk in ipairs(all) do
    if sk.isPrimary then
      skills[#skills + 1] = sk
    else
      effects[#effects + 1] = sk
    end
  end

  local contrib = buildDamageContribution(session)
  local cBits = {}
  if contrib and contrib.parts then
    for _, p in ipairs(contrib.parts) do
      if (p.pct or 0) >= 0.02 then
        cBits[#cBits + 1] = string.format("%s %s", p.label, p.pctTxt)
      end
    end
  end
  local skillShown = math.min(DMG_SKILL_ROWS, #skills)
  local fxShown = math.min(DMG_FX_ROWS, #effects)
  ui.meta:SetText(string.format(
    "%s  ·  %s DPS  ·  total %s  ·  %d skills / %d effects (showing %d / %d)\n|cC0A060Contribution:|r %s",
    truncateText(session.lastTargetName or "fight", 48),
    fmtDps(sessionAvgDps(session)),
    fmtInt(session.totalDamage),
    #skills, #effects, skillShown, fxShown,
    (#cBits > 0) and table.concat(cBits, "  ·  ") or "—"
  ))
  ui.skillTitle:SetText(string.format(
    "SKILLS  ·  F / B / LA / HA / ULT  (%d%s)",
    #skills,
    (#skills > DMG_SKILL_ROWS) and (" · top " .. tostring(DMG_SKILL_ROWS)) or ""
  ))
  ui.fxTitle:SetText(string.format(
    "EFFECTS  ·  E / S  (%d%s)",
    #effects,
    (#effects > DMG_FX_ROWS) and (" · top " .. tostring(DMG_FX_ROWS)) or ""
  ))

  for i = 1, DMG_SKILL_ROWS do
    fillDamageRow(ui.skillRows[i], skills[i], 34)
  end
  for i = 1, DMG_FX_ROWS do
    fillDamageRow(ui.fxRows[i], effects[i], 28)
  end
end

---------------------------------------------------------------------
-- Buffs/Debuffs: 3 columns
--   1 Always-on (self)  ·  2 Sustained+Sit (self)  ·  3 Target debuffs
---------------------------------------------------------------------
local BUFF_MID_ROWS = 12
local BUFF_DEB_ROWS = 12

local function createBuffsUI(screen)
  if screen.buffsUI and not screen.buffsUI._v3181 then screen.buffsUI = nil end
  if screen.buffsUI then return screen.buffsUI end
  ensureContentHost(screen)
  local panel = screen.contentPanels and screen.contentPanels.buffs
  if not panel then return nil end
  local ui = { panel = panel, rows = {}, midRows = {}, sideRows = {}, _v3181 = true }

  ui.root = WM:CreateControl("DM2StatsMenuBuffRootV4", panel, CT_CONTROL)
  ui.root:SetAnchor(TOPLEFT, panel, TOPLEFT, 4, 2)
  stampForeground(ui.root, 55)
  ui.title = makeDashLabel(ui.root, "DM2StatsMenuBuffTitleV4", 16, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.title:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, 0)
  ui.title:SetText("BUFFS / DEBUFFS")
  ui.meta = makeDashLabel(ui.root, "DM2StatsMenuBuffMetaV4", 12, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.meta:SetAnchor(TOPLEFT, ui.title, BOTTOMLEFT, 0, 1)
  ui.legend = makeDashLabel(ui.root, "DM2StatsMenuBuffLegendV4", 11, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.legend:SetAnchor(TOPLEFT, ui.meta, BOTTOMLEFT, 0, 1)
  ui.legend:SetText("1 Always-on  ·  2 Sustained/Sit (self)  ·  3 Target status you applied")

  -- Col 1: Always-on
  ui.table = WM:CreateControl("DM2StatsMenuBuffCol1V4", ui.root, CT_CONTROL)
  local tbg = makeSectionFrame(ui.table, "DM2StatsMenuBuffCol1BGV4", true)
  tbg:SetAnchorFill(ui.table)
  ui.mainTitle = makeDashLabel(ui.table, "DM2StatsMenuBuffCol1TitleV4", 12, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.mainTitle:SetText("ALWAYS-ON")
  ui.hdrName = makeDashLabel(ui.table, "DM2StatsMenuBuffCol1HdrN", 10, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.hdrName:SetText("Buff")
  ui.hdrSrc = makeDashLabel(ui.table, "DM2StatsMenuBuffCol1HdrS", 10, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.hdrSrc:SetText("Src")
  ui.hdrUp = makeDashLabel(ui.table, "DM2StatsMenuBuffCol1HdrU", 10, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.hdrUp:SetText("Up%")
  ui.hdrUp:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  ui.hdrAct = makeDashLabel(ui.table, "DM2StatsMenuBuffCol1HdrA", 10, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.hdrAct:SetText("Act")
  ui.hdrAct:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  ui.hdrApps = makeDashLabel(ui.table, "DM2StatsMenuBuffCol1HdrP", 10, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.hdrApps:SetText("×")
  ui.hdrApps:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  for i = 1, BUFF_MAIN_ROWS do
    local row = WM:CreateControl("DM2StatsMenuBuffC1Row" .. i, ui.table, CT_CONTROL)
    local chip = makeDashLabel(row, "DM2StatsMenuBuffC1Chip" .. i, 10, THEME.frontR, THEME.frontG, THEME.frontB, 1)
    local icon = WM:CreateControl("DM2StatsMenuBuffC1Icon" .. i, row, CT_TEXTURE)
    icon:SetDimensions(18, 18)
    stampForeground(icon, 110)
    local name = makeDashLabel(row, "DM2StatsMenuBuffC1Name" .. i, 12, THEME.textR, THEME.textG, THEME.textB, 1)
    local barBg = WM:CreateControl("DM2StatsMenuBuffC1BarBg" .. i, row, CT_BACKDROP)
    barBg:SetCenterColor(0.12, 0.12, 0.14, 0.55)
    barBg:SetEdgeColor(0, 0, 0, 0)
    local barFg = WM:CreateControl("DM2StatsMenuBuffC1BarFg" .. i, barBg, CT_BACKDROP)
    barFg:SetCenterColor(0.55, 0.78, 0.42, 0.9)
    barFg:SetEdgeColor(0, 0, 0, 0)
    barFg:SetAnchor(TOPLEFT, barBg, TOPLEFT, 0, 0)
    barFg:SetDimensions(2, 4)
    local src = makeDashLabel(row, "DM2StatsMenuBuffC1Src" .. i, 11, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
    local up = makeDashLabel(row, "DM2StatsMenuBuffC1Up" .. i, 11, THEME.textR, THEME.textG, THEME.textB, 1)
    up:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    local act = makeDashLabel(row, "DM2StatsMenuBuffC1Act" .. i, 11, THEME.textR, THEME.textG, THEME.textB, 1)
    act:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    local apps = makeDashLabel(row, "DM2StatsMenuBuffC1Apps" .. i, 11, THEME.textR, THEME.textG, THEME.textB, 1)
    apps:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    ui.rows[i] = {
      row = row, chip = chip, icon = icon, name = name, barBg = barBg, barFg = barFg,
      src = src, up = up, act = act, apps = apps,
    }
  end

  -- Col 2: Sustained + Situational (self)
  ui.mid = WM:CreateControl("DM2StatsMenuBuffCol2V4", ui.root, CT_CONTROL)
  local mbg = makeSectionFrame(ui.mid, "DM2StatsMenuBuffCol2BGV4", true)
  mbg:SetAnchorFill(ui.mid)
  ui.midTitle = makeDashLabel(ui.mid, "DM2StatsMenuBuffCol2TitleV4", 12, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.midTitle:SetText("SUSTAINED + SIT")
  ui.midHdrName = makeDashLabel(ui.mid, "DM2StatsMenuBuffCol2HdrN", 10, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.midHdrName:SetText("Buff")
  ui.midHdrSrc = makeDashLabel(ui.mid, "DM2StatsMenuBuffCol2HdrS", 10, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.midHdrSrc:SetText("Src")
  ui.midHdrEff = makeDashLabel(ui.mid, "DM2StatsMenuBuffCol2HdrE", 10, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.midHdrEff:SetText("Effect")
  ui.midHdrUp = makeDashLabel(ui.mid, "DM2StatsMenuBuffCol2HdrU", 10, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.midHdrUp:SetText("Up%")
  ui.midHdrUp:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  for i = 1, BUFF_MID_ROWS do
    local row = WM:CreateControl("DM2StatsMenuBuffC2Row" .. i, ui.mid, CT_CONTROL)
    local name = makeDashLabel(row, "DM2StatsMenuBuffC2Name" .. i, 11, THEME.textR, THEME.textG, THEME.textB, 1)
    local src = makeDashLabel(row, "DM2StatsMenuBuffC2Src" .. i, 11, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
    local eff = makeDashLabel(row, "DM2StatsMenuBuffC2Eff" .. i, 11, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
    local up = makeDashLabel(row, "DM2StatsMenuBuffC2Up" .. i, 11, THEME.textR, THEME.textG, THEME.textB, 1)
    up:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    local barBg = WM:CreateControl("DM2StatsMenuBuffC2BarBg" .. i, row, CT_BACKDROP)
    barBg:SetCenterColor(0.12, 0.12, 0.14, 0.55)
    barBg:SetEdgeColor(0, 0, 0, 0)
    local barFg = WM:CreateControl("DM2StatsMenuBuffC2BarFg" .. i, barBg, CT_BACKDROP)
    barFg:SetCenterColor(0.55, 0.78, 0.42, 0.9)
    barFg:SetEdgeColor(0, 0, 0, 0)
    barFg:SetAnchor(TOPLEFT, barBg, TOPLEFT, 0, 0)
    barFg:SetDimensions(2, 3)
    ui.midRows[i] = { row = row, name = name, src = src, eff = eff, up = up, barBg = barBg, barFg = barFg }
  end

  -- Col 3: Target debuffs
  ui.side = WM:CreateControl("DM2StatsMenuBuffCol3V4", ui.root, CT_CONTROL)
  local sbg = makeSectionFrame(ui.side, "DM2StatsMenuBuffCol3BGV4", true)
  sbg:SetAnchorFill(ui.side)
  ui.sideTitle = makeDashLabel(ui.side, "DM2StatsMenuBuffCol3TitleV4", 12, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.sideTitle:SetText("TARGET DEBUFFS")
  ui.sideHdrName = makeDashLabel(ui.side, "DM2StatsMenuBuffCol3HdrN", 10, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.sideHdrName:SetText("Status")
  ui.sideHdrSrc = makeDashLabel(ui.side, "DM2StatsMenuBuffCol3HdrS", 10, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.sideHdrSrc:SetText("Kind")
  ui.sideHdrDetail = makeDashLabel(ui.side, "DM2StatsMenuBuffCol3HdrD", 10, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.sideHdrDetail:SetText("Detail")
  ui.sideHdrTier = makeDashLabel(ui.side, "DM2StatsMenuBuffCol3HdrA", 10, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.sideHdrTier:SetText("Apps")
  ui.sideHdrTier:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  ui.sideHdrUp = makeDashLabel(ui.side, "DM2StatsMenuBuffCol3HdrU", 10, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.sideHdrUp:SetText("Up%")
  ui.sideHdrUp:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  for i = 1, BUFF_DEB_ROWS do
    local row = WM:CreateControl("DM2StatsMenuBuffC3RowV2" .. i, ui.side, CT_CONTROL)
    local name = makeDashLabel(row, "DM2StatsMenuBuffC3NameV2" .. i, 11, THEME.textR, THEME.textG, THEME.textB, 1)
    local src = makeDashLabel(row, "DM2StatsMenuBuffC3SrcV2" .. i, 11, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
    local detail = makeDashLabel(row, "DM2StatsMenuBuffC3DetV2" .. i, 11, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
    local tier = makeDashLabel(row, "DM2StatsMenuBuffC3AppsV2" .. i, 11, THEME.textR, THEME.textG, THEME.textB, 1)
    tier:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    local up = makeDashLabel(row, "DM2StatsMenuBuffC3UpV2" .. i, 11, THEME.textR, THEME.textG, THEME.textB, 1)
    up:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    local barBg = WM:CreateControl("DM2StatsMenuBuffC3BarBg" .. i, row, CT_BACKDROP)
    barBg:SetCenterColor(0.12, 0.12, 0.14, 0.55)
    barBg:SetEdgeColor(0, 0, 0, 0)
    local barFg = WM:CreateControl("DM2StatsMenuBuffC3BarFg" .. i, barBg, CT_BACKDROP)
    barFg:SetCenterColor(0.55, 0.78, 0.42, 0.9)
    barFg:SetEdgeColor(0, 0, 0, 0)
    barFg:SetAnchor(TOPLEFT, barBg, TOPLEFT, 0, 0)
    barFg:SetDimensions(2, 3)
    ui.sideRows[i] = { row = row, name = name, src = src, detail = detail, tier = tier, up = up, barBg = barBg, barFg = barFg }
  end
  ui.sideNote = makeDashLabel(ui.side, "DM2StatsMenuBuffC3NoteV4", 11, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  if ui.sideNote.SetWrapMode then ui.sideNote:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE or TEXT_WRAP_MODE_ELLIPSIS) end
  if ui.sideNote.SetMaxLineCount then ui.sideNote:SetMaxLineCount(2) end
  ui.sideNote:SetText("Skill hit = your skill landing on the dummy (high % is normal). Debuff / Status = lasting effects like Breach.")

  ui.empty = makeDashLabel(ui.root, "DM2StatsMenuBuffEmptyV4", 15, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.empty:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, 60)
  ui.empty:SetHidden(true)
  -- Phase 2.5.4: pen discoverability (link to Insights recipe — not a full duplicate)
  ui.penFooter = makeDashLabel(ui.root, "DM2StatsMenuBuffPenFootV4", 12, 0.85, 0.78, 0.45, 1)
  ui.penFooter:SetMaxLineCount(2)
  ui.raidLegend = makeDashLabel(ui.root, "DM2StatsMenuBuffRaidLegV1", 11, 0.78, 0.72, 0.52, 1)
  ui.raidLegend:SetMaxLineCount(4)
  ui.raidLegend:SetText(
    "Raid essentials (Major / Minor):  Berserk +10/+5% dmg done  ·  Slayer +10/+5% vs monsters  ·  Force +20/+10% crit dmg   ·   "
      .. "Courage +430/+215 Wpn/Spell  ·  Brutality/Sorcery +20/+10%  ·  Heroism 3/1 ult per 1.5s   ·   "
      .. "Breach −5948/−2974 armor  ·  Brittle +20/+10% crit taken  ·  Vulnerability +10/+5% dmg taken"
  )
  screen.buffsUI = ui
  return ui
end

local function layoutBuffsUI(ui, hostW, hostH)
  if not ui or not ui.root then return end
  local W = math.max(520, (hostW or 900) - 6)
  local H = math.max(400, (hostH or 700) - 6)
  ui.root:ClearAnchors()
  ui.root:SetAnchor(TOPLEFT, ui.panel, TOPLEFT, 4, 2)
  ui.root:SetDimensions(W, H)
  ui.title:SetWidth(W)
  ui.meta:SetWidth(W)
  ui.legend:SetWidth(W)
  ui.empty:SetWidth(W)

  local footH = 72
  local bodyY, bodyH = 48, H - 52 - footH
  if ui.raidLegend then
    ui.raidLegend:ClearAnchors()
    ui.raidLegend:SetAnchor(BOTTOMLEFT, ui.root, BOTTOMLEFT, 4, -22)
    ui.raidLegend:SetWidth(W - 8)
    if ui.raidLegend.SetWrapMode then
      ui.raidLegend:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE or TEXT_WRAP_MODE_ELLIPSIS)
    end
  end
  if ui.penFooter then
    ui.penFooter:ClearAnchors()
    ui.penFooter:SetAnchor(BOTTOMLEFT, ui.root, BOTTOMLEFT, 4, -2)
    ui.penFooter:SetWidth(W - 8)
  end
  local gap = 6
  local colW = math.floor((W - gap * 2) / 3)

  ui.table:ClearAnchors()
  ui.table:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, bodyY)
  ui.table:SetDimensions(colW, bodyH)
  ui.mid:ClearAnchors()
  ui.mid:SetAnchor(TOPLEFT, ui.root, TOPLEFT, colW + gap, bodyY)
  ui.mid:SetDimensions(colW, bodyH)
  ui.side:ClearAnchors()
  ui.side:SetAnchor(TOPLEFT, ui.root, TOPLEFT, (colW + gap) * 2, bodyY)
  ui.side:SetDimensions(colW, bodyH)

  -- Col 1: long Buff name · Src near Up% · Act · ×
  ui.mainTitle:ClearAnchors()
  ui.mainTitle:SetAnchor(TOPLEFT, ui.table, TOPLEFT, 8, 4)
  ui.mainTitle:SetWidth(colW - 16)
  local pad = 6
  local nameX = 34
  local upW, actW, appsW, srcW1 = 42, 40, 28, 40
  local nameW = math.max(100, colW - pad - nameX - srcW1 - upW - actW - appsW - 20)
  local upX = colW - pad - appsW - actW - upW - 6
  local srcX = upX - srcW1 - 4
  local actX = upX + upW + 2
  local appsX = actX + actW + 2
  local function placeHdr1(lbl, hx, hw)
    lbl:ClearAnchors()
    lbl:SetAnchor(TOPLEFT, ui.table, TOPLEFT, hx, 22)
    lbl:SetWidth(hw)
  end
  placeHdr1(ui.hdrName, nameX, nameW)
  placeHdr1(ui.hdrSrc, srcX, srcW1)
  placeHdr1(ui.hdrUp, upX, upW)
  placeHdr1(ui.hdrAct, actX, actW)
  placeHdr1(ui.hdrApps, appsX, appsW)
  local rowTop = 38
  local rowH = math.floor((bodyH - rowTop - 4) / BUFF_MAIN_ROWS)
  if rowH < 18 then rowH = 18 end
  if rowH > 26 then rowH = 26 end
  for i = 1, BUFF_MAIN_ROWS do
    local r = ui.rows[i]
    if r then
      r.row:ClearAnchors()
      r.row:SetAnchor(TOPLEFT, ui.table, TOPLEFT, pad, rowTop + (i - 1) * rowH)
      r.row:SetDimensions(colW - pad * 2, rowH - 1)
      r.chip:ClearAnchors()
      r.chip:SetAnchor(LEFT, r.row, LEFT, 0, 0)
      r.icon:ClearAnchors()
      r.icon:SetAnchor(LEFT, r.row, LEFT, 12, 0)
      r.name:ClearAnchors()
      r.name:SetAnchor(TOPLEFT, r.row, TOPLEFT, nameX - pad, 1)
      r.name:SetWidth(nameW)
      r.name:SetMaxLineCount(1)
      r.barBg:ClearAnchors()
      r.barBg:SetAnchor(BOTTOMLEFT, r.row, BOTTOMLEFT, nameX - pad, 0)
      r.barBg:SetDimensions(math.min(110, nameW), 3)
      local function place(lbl, cx, cw)
        lbl:ClearAnchors()
        lbl:SetAnchor(TOPLEFT, r.row, TOPLEFT, cx - pad, 2)
        lbl:SetWidth(cw)
      end
      place(r.src, srcX, srcW1)
      place(r.up, upX, upW)
      place(r.act, actX, actW)
      place(r.apps, appsX, appsW)
    end
  end

  -- Col 2: Buff name · Effect (left + ~20% wider) · Src near Up% · Up%
  ui.midTitle:ClearAnchors()
  ui.midTitle:SetAnchor(TOPLEFT, ui.mid, TOPLEFT, 8, 4)
  ui.midTitle:SetWidth(colW - 16)
  local mUpW = 40
  local mSrcW = 36
  local mUpX = colW - 14 - mUpW
  local mSrcX = mUpX - mSrcW - 4
  local mNameW = math.max(96, math.floor(colW * 0.46))
  local mEffX = mNameW + 4
  local mEffW = math.max(72, math.floor((mSrcX - mEffX - 4) * 1.05))
  if mEffX + mEffW > mSrcX - 2 then mEffW = math.max(60, mSrcX - mEffX - 2) end
  ui.midHdrName:ClearAnchors()
  ui.midHdrName:SetAnchor(TOPLEFT, ui.mid, TOPLEFT, 8, 22)
  ui.midHdrName:SetWidth(mNameW)
  ui.midHdrEff:ClearAnchors()
  ui.midHdrEff:SetAnchor(TOPLEFT, ui.mid, TOPLEFT, 8 + mEffX, 22)
  ui.midHdrEff:SetWidth(mEffW)
  ui.midHdrSrc:ClearAnchors()
  ui.midHdrSrc:SetAnchor(TOPLEFT, ui.mid, TOPLEFT, 8 + mSrcX, 22)
  ui.midHdrSrc:SetWidth(mSrcW)
  ui.midHdrUp:ClearAnchors()
  ui.midHdrUp:SetAnchor(TOPLEFT, ui.mid, TOPLEFT, 8 + mUpX, 22)
  ui.midHdrUp:SetWidth(mUpW)
  local mH = math.floor((bodyH - 40) / BUFF_MID_ROWS)
  if mH < 16 then mH = 16 end
  if mH > 22 then mH = 22 end
  for i = 1, BUFF_MID_ROWS do
    local r = ui.midRows[i]
    if r then
      r.row:ClearAnchors()
      r.row:SetAnchor(TOPLEFT, ui.mid, TOPLEFT, 6, 38 + (i - 1) * mH)
      r.row:SetDimensions(colW - 12, mH - 1)
      r.name:ClearAnchors()
      r.name:SetAnchor(LEFT, r.row, LEFT, 0, 0)
      r.name:SetWidth(mNameW)
      r.name:SetMaxLineCount(1)
      if r.barBg then
        r.barBg:ClearAnchors()
        r.barBg:SetAnchor(BOTTOMLEFT, r.row, BOTTOMLEFT, 0, 0)
        r.barBg:SetDimensions(math.min(100, mNameW), 3)
      end
      r.eff:ClearAnchors()
      r.eff:SetAnchor(LEFT, r.row, LEFT, mEffX, 0)
      r.eff:SetWidth(mEffW)
      r.eff:SetMaxLineCount(1)
      r.src:ClearAnchors()
      r.src:SetAnchor(LEFT, r.row, LEFT, mSrcX, 0)
      r.src:SetWidth(mSrcW)
      r.up:ClearAnchors()
      r.up:SetAnchor(LEFT, r.row, LEFT, mUpX, 0)
      r.up:SetWidth(mUpW)
    end
  end

  -- Col 3: Status (wide) · Kind · Detail · Apps · Up%
  -- Kind/detail sit ~20 chars right of the old 28% name so "Minor Vulnerability" is fully visible
  ui.sideTitle:ClearAnchors()
  ui.sideTitle:SetAnchor(TOPLEFT, ui.side, TOPLEFT, 8, 4)
  ui.sideTitle:SetWidth(colW - 16)
  local sUpW, sAppsW, sKindW = 38, 34, 56
  local sUpX = colW - 14 - sUpW
  local sAppsX = sUpX - sAppsW - 3
  local nW = math.max(132, math.floor(colW * 0.42))
  local sKindX = nW + 10
  local sDetX = sKindX + sKindW + 4
  local sDetW = math.max(52, sAppsX - sDetX - 3)
  if sDetX + sDetW > sAppsX - 3 then
    sDetW = math.max(44, sAppsX - sDetX - 3)
  end
  if nW + 10 > sKindX then nW = math.max(120, sKindX - 10) end
  ui.sideHdrName:ClearAnchors()
  ui.sideHdrName:SetAnchor(TOPLEFT, ui.side, TOPLEFT, 8, 22)
  ui.sideHdrName:SetWidth(nW)
  ui.sideHdrSrc:ClearAnchors()
  ui.sideHdrSrc:SetAnchor(TOPLEFT, ui.side, TOPLEFT, 8 + sKindX, 22)
  ui.sideHdrSrc:SetWidth(sKindW)
  if ui.sideHdrDetail then
    ui.sideHdrDetail:ClearAnchors()
    ui.sideHdrDetail:SetAnchor(TOPLEFT, ui.side, TOPLEFT, 8 + sDetX, 22)
    ui.sideHdrDetail:SetWidth(sDetW)
  end
  ui.sideHdrTier:ClearAnchors()
  ui.sideHdrTier:SetAnchor(TOPLEFT, ui.side, TOPLEFT, 8 + sAppsX, 22)
  ui.sideHdrTier:SetWidth(sAppsW)
  ui.sideHdrUp:ClearAnchors()
  ui.sideHdrUp:SetAnchor(TOPLEFT, ui.side, TOPLEFT, 8 + sUpX, 22)
  ui.sideHdrUp:SetWidth(sUpW)
  local noteH = (ui.sideNote and not ui.sideNote:IsHidden()) and 32 or 0
  if ui.sideNote then
    ui.sideNote:ClearAnchors()
    ui.sideNote:SetAnchor(BOTTOMLEFT, ui.side, BOTTOMLEFT, 8, -4)
    ui.sideNote:SetWidth(colW - 16)
  end
  local sH = math.floor((bodyH - 40 - noteH) / BUFF_DEB_ROWS)
  if sH < 16 then sH = 16 end
  if sH > 22 then sH = 22 end
  for i = 1, BUFF_DEB_ROWS do
    local r = ui.sideRows[i]
    if r then
      r.row:ClearAnchors()
      r.row:SetAnchor(TOPLEFT, ui.side, TOPLEFT, 6, 38 + (i - 1) * sH)
      r.row:SetDimensions(colW - 12, sH - 1)
      r.name:ClearAnchors()
      r.name:SetAnchor(LEFT, r.row, LEFT, 0, 0)
      r.name:SetWidth(nW)
      r.name:SetMaxLineCount(1)
      if r.barBg then
        r.barBg:ClearAnchors()
        r.barBg:SetAnchor(BOTTOMLEFT, r.row, BOTTOMLEFT, 0, 0)
        r.barBg:SetDimensions(math.min(90, nW), 3)
      end
      r.src:ClearAnchors()
      r.src:SetAnchor(LEFT, r.row, LEFT, sKindX, 0)
      r.src:SetWidth(sKindW)
      if r.detail then
        r.detail:ClearAnchors()
        r.detail:SetAnchor(LEFT, r.row, LEFT, sDetX, 0)
        r.detail:SetWidth(sDetW)
        r.detail:SetMaxLineCount(1)
      end
      r.tier:ClearAnchors()
      r.tier:SetAnchor(LEFT, r.row, LEFT, sAppsX, 0)
      r.tier:SetWidth(sAppsW)
      r.up:ClearAnchors()
      r.up:SetAnchor(LEFT, r.row, LEFT, sUpX, 0)
      r.up:SetWidth(sUpW)
    end
  end
end

local function fillBuffSelfRow(r, b)
  if not r then return end
  if not b then
    r.row:SetHidden(true)
    return
  end
  r.row:SetHidden(false)
  local bid = tonumber(b.id) or 0
  r.name:SetText(formatAbilityDisplay(b.name, bid, 36))
  r.src:SetText(displayName(b.sourceTxt or "", 10))
  r.up:SetText(b.uptimeTxt or "")
  if r.act then r.act:SetText(b.activeTxt or "") end
  if r.apps then r.apps:SetText(b.appsTxt or "") end
  if r.barBg and r.barFg then
    local up = tonumber(b.uptime) or tonumber(b.share) or 0
    local bgW = r.barBg:GetWidth() or 100
    if bgW < 10 then bgW = 100 end
    r.barFg:SetDimensions(math.max(2, math.floor(bgW * math.min(1, up))), 3)
    if up >= 0.85 then r.barFg:SetCenterColor(0.45, 0.88, 0.48, 0.9)
    elseif up >= 0.5 then r.barFg:SetCenterColor(0.92, 0.72, 0.32, 0.9)
    else r.barFg:SetCenterColor(0.88, 0.38, 0.30, 0.9) end
  end
  if r.chip then
    local chip = barChipLabel(b.bar)
    r.chip:SetText(chip)
    local cr, cg, cb, ca = barChipColor(b.bar)
    r.chip:SetColor(cr, cg, cb, ca)
    r.chip:SetHidden(chip == "")
  end
  if r.icon then
    if b.icon then
      r.icon:SetTexture(b.icon)
      r.icon:SetHidden(false)
      r.icon:SetColor(1, 1, 1, 1)
    else
      r.icon:SetHidden(true)
    end
  end
  if r.barFg and r.barBg then
    local share = tonumber(b.share) or 0
    local bgW = r.barBg:GetWidth() or 80
    if bgW < 10 then bgW = 80 end
    r.barFg:SetDimensions(math.max(2, math.floor(bgW * math.min(1, share))), 3)
  end
end

local function refreshBuffsUI(screen, session)
  local ui = createBuffsUI(screen)
  if not ui then return end
  local hostW, hostH = layoutContentHost(screen)
  layoutBuffsUI(ui, hostW, hostH)
  if not session then
    ui.meta:SetText("No fight selected")
    ui.empty:SetText("History is empty.")
    ui.empty:SetHidden(false)
    ui.table:SetHidden(true)
    if ui.mid then ui.mid:SetHidden(true) end
    ui.side:SetHidden(true)
    if ui.penFooter then ui.penFooter:SetText("") end
    return
  end
  ui.empty:SetHidden(true)
  ui.table:SetHidden(false)
  if ui.mid then ui.mid:SetHidden(false) end
  ui.side:SetHidden(false)

  -- 2.5.4 pen context footer (uptime cues only; full recipe on Insights §2)
  if ui.penFooter then
    local profile = getActiveContentProfile()
    local majB = buffUptimeByNameKey(session, "major breach")
    local minB = buffUptimeByNameKey(session, "minor breach")
    local crusher = buffUptimeByNameKey(session, "crusher")
    -- Also check target debuffs for breach names
    if majB <= 0 or minB <= 0 or crusher <= 0 then
      if type(session.targetDebuffs) == "table" then
        local dur = math.max(1, tonumber(session.durationMs) or 1)
        for _, d in pairs(session.targetDebuffs) do
          if type(d) == "table" and d.name then
            local low = string.lower(tostring(d.name))
            local up = (tonumber(d.activeMs) or 0) / dur
            if majB <= 0 and string.find(low, "major breach", 1, true) then majB = up end
            if minB <= 0 and string.find(low, "minor breach", 1, true) then minB = up end
            if crusher <= 0 and string.find(low, "crusher", 1, true) then crusher = up end
          end
        end
      end
    end
    ui.penFooter:SetText(string.format(
      "Pen context (%s): Major Breach %s · Minor Breach %s · Crusher %s  ·  Effective pen = personal sheet + group resist reduction — full recipe: Insights: DPS §2",
      profile.shortLabel or profile.label or "trial-prep",
      fmtPct(majB), fmtPct(minB), fmtPct(crusher)
    ))
  end

  local always, sust, sit, total = buildBuffTierLists(session)
  local midList = {}
  for _, b in ipairs(sust) do midList[#midList + 1] = b end
  for _, b in ipairs(sit) do midList[#midList + 1] = b end
  local debuffRows = buildTargetDebuffRows(session, BUFF_DEB_ROWS)

  ui.meta:SetText(string.format(
    "Self %d (Always-on %d · Sustained %d · Sit %d)  ·  Target debuffs %d",
    total, #always, #sust, #sit, #debuffRows
  ))
  ui.mainTitle:SetText(string.format("ALWAYS-ON  (%d)", #always))
  if ui.midTitle then ui.midTitle:SetText(string.format("SUSTAINED + SIT  (%d)", #midList)) end
  ui.sideTitle:SetText(string.format("TARGET DEBUFFS  (%d)", #debuffRows))

  for i = 1, BUFF_MAIN_ROWS do
    fillBuffSelfRow(ui.rows[i], always[i])
  end

  for i = 1, BUFF_MID_ROWS do
    local r = ui.midRows and ui.midRows[i]
    local b = midList[i]
    if r then
      if b then
        r.row:SetHidden(false)
        -- Include ability id when known (Fancy Bar / Wardrobe reference)
        local bid = tonumber(b.id) or 0
        r.name:SetText(formatAbilityDisplay(b.name, bid, 32))
        r.src:SetText(displayName(b.sourceTxt or "", 8))
        local eff = b.effectTxt or "—"
        r.eff:SetText(displayName(eff, 32))
        r.up:SetText(b.uptimeTxt or "")
        if r.barBg and r.barFg then
          local up = tonumber(b.uptime) or tonumber(b.share) or 0
          local bgW = r.barBg:GetWidth() or 90
          if bgW < 10 then bgW = 90 end
          r.barFg:SetDimensions(math.max(2, math.floor(bgW * math.min(1, up))), 3)
          if up >= 0.85 then r.barFg:SetCenterColor(0.45, 0.88, 0.48, 0.9)
          elseif up >= 0.5 then r.barFg:SetCenterColor(0.92, 0.72, 0.32, 0.9)
          else r.barFg:SetCenterColor(0.88, 0.38, 0.30, 0.9) end
        end
        if b.effectTxt and b.effectTxt ~= "" and b.effectTxt ~= "—" then
          r.eff:SetColor(0.75, 0.88, 0.95, 1)
        else
          r.eff:SetColor(THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
        end
      else
        r.row:SetHidden(true)
      end
    end
  end

  for i = 1, BUFF_DEB_ROWS do
    local r = ui.sideRows[i]
    local d = debuffRows[i]
    if r then
      if d then
        r.row:SetHidden(false)
        -- Name only here — id lives in Detail. Stuffing " · id N" was clipping Status.
        r.name:SetText(displayName(d.name or "?", 40))
        r.src:SetText(displayName(d.kindTxt or d.kind or "Skill hit", 12))
        if r.detail then
          r.detail:SetText(displayName(d.sourceTxt or "", 28))
        end
        r.tier:SetText(d.appsTxt or "0")
        r.up:SetText(d.uptimeTxt or "")
        if r.barBg and r.barFg then
          local up = tonumber(d.uptime) or tonumber(d.share) or 0
          local bgW = r.barBg:GetWidth() or 80
          if bgW < 10 then bgW = 80 end
          r.barFg:SetDimensions(math.max(2, math.floor(bgW * math.min(1, up))), 3)
          if up >= 0.85 then r.barFg:SetCenterColor(0.45, 0.88, 0.48, 0.9)
          elseif up >= 0.5 then r.barFg:SetCenterColor(0.92, 0.72, 0.32, 0.9)
          else r.barFg:SetCenterColor(0.88, 0.38, 0.30, 0.9) end
        end
        if d.kind == "CC" then
          r.src:SetColor(0.98, 0.72, 0.35, 1)
        elseif d.kind == "Status" then
          r.src:SetColor(0.75, 0.55, 0.95, 1)
        elseif d.kind == "Debuff" then
          r.src:SetColor(0.95, 0.45, 0.45, 1)
        else
          r.src:SetColor(THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
        end
      else
        r.row:SetHidden(i ~= 1 or #debuffRows > 0)
        if i == 1 and #debuffRows == 0 then
          r.row:SetHidden(false)
          r.name:SetText("(none this fight — Off Balance needs target effect events)")
          r.src:SetText("")
          if r.detail then r.detail:SetText("") end
          r.tier:SetText("")
          r.up:SetText("")
        end
      end
    end
  end
end

---------------------------------------------------------------------
-- Build & Sets (was Procs): parse build strip + set contribution
---------------------------------------------------------------------
local BUILD_SET_PROC_ROWS = 6
local BUILD_SET_CP_ROWS = 8

local function createProcsUI(screen)
  if screen.procsUI and not screen.procsUI._v31719 then screen.procsUI = nil end
  if screen.procsUI then return screen.procsUI end
  ensureContentHost(screen)
  local panel = screen.contentPanels and screen.contentPanels.procs
  if not panel then return nil end
  local ui = {
    panel = panel,
    rows = {},
    cpRows = {},
    barIcons = { front = {}, back = {} },
    buildLines = {},
    _v31719 = true,
  }

  ui.root = WM:CreateControl("DM2StatsMenuBuildSetsRootV4", panel, CT_CONTROL)
  ui.root:SetAnchor(TOPLEFT, panel, TOPLEFT, 8, 4)
  stampForeground(ui.root, 55)
  ui.title = makeDashLabel(ui.root, "DM2StatsMenuBuildSetsTitleV4", 16, 1.0, 0.90, 0.50, 1)
  ui.title:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, 0)
  ui.title:SetText("BUILD & SETS")
  ui.meta = makeDashLabel(ui.root, "DM2StatsMenuBuildSetsMetaV4", 12, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.meta:SetAnchor(TOPLEFT, ui.title, BOTTOMLEFT, 0, 2)

  -- Top: char build for this parse
  ui.buildPanel = WM:CreateControl("DM2StatsMenuBuildPanelV4", ui.root, CT_CONTROL)
  local bbg = makeSectionFrame(ui.buildPanel, "DM2StatsMenuBuildPanelBGV4", true)
  bbg:SetAnchorFill(ui.buildPanel)
  ui.buildTitle = makeDashLabel(ui.buildPanel, "DM2StatsMenuBuildPanelTitleV4", 13, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.buildTitle:SetText("CHAR BUILD  ·  this parse")
  ui.buildProv = makeDashLabel(ui.buildPanel, "DM2StatsMenuBuildProvV4", 10, 0.85, 0.78, 0.45, 1)
  ui.frontTitle = makeDashLabel(ui.buildPanel, "DM2StatsMenuBuildFrontV4", 12, THEME.frontR, THEME.frontG, THEME.frontB, 1)
  ui.frontTitle:SetText("FRONT")
  ui.backTitle = makeDashLabel(ui.buildPanel, "DM2StatsMenuBuildBackV4", 12, THEME.backR, THEME.backG, THEME.backB, 1)
  ui.backTitle:SetText("BACK")
  for _, barKey in ipairs({ "front", "back" }) do
    for i = 1, 6 do
      local slotBg = WM:CreateControl("DM2StatsMenuBuild" .. barKey .. "Slot" .. i, ui.buildPanel, CT_BACKDROP)
      slotBg:SetDimensions(28, 28)
      slotBg:SetCenterColor(0.14, 0.12, 0.09, 0.95)
      slotBg:SetEdgeColor(THEME.cardEdgeR, THEME.cardEdgeG, THEME.cardEdgeB, 0.75)
      stampBackground(slotBg, 4)
      local icon = WM:CreateControl("DM2StatsMenuBuild" .. barKey .. "Icon" .. i, slotBg, CT_TEXTURE)
      icon:SetDimensions(26, 26)
      icon:SetAnchor(CENTER, slotBg, CENTER, 0, 0)
      stampForeground(icon, 110)
      ui.barIcons[barKey][i] = { bg = slotBg, icon = icon }
    end
  end
  for i = 1, 5 do
    ui.buildLines[i] = makeDashLabel(ui.buildPanel, "DM2StatsMenuBuildLineV4_" .. i, 12, THEME.textR, THEME.textG, THEME.textB, 1)
  end

  -- Bottom: set contribution
  ui.table = WM:CreateControl("DM2StatsMenuBuildSetsTableV4", ui.root, CT_CONTROL)
  local tbg = makeSectionFrame(ui.table, "DM2StatsMenuBuildSetsTableBGV4", true)
  tbg:SetAnchorFill(ui.table)
  ui.setTitle = makeDashLabel(ui.table, "DM2StatsMenuBuildSetsSetTitleV4", 13, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.setTitle:SetText("SET / PROC CONTRIBUTION")
  ui.legend = makeDashLabel(ui.table, "DM2StatsMenuBuildSetsLegendV4", 11, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.legend:SetText("Share = % of fight damage · enriched from this parse’s set attribution")

  ui.hdrName = makeDashLabel(ui.table, "DM2StatsMenuBuildSetsHdrName", 11, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.hdrName:SetText("Set / Proc")
  ui.hdrAmt = makeDashLabel(ui.table, "DM2StatsMenuBuildSetsHdrAmt", 11, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.hdrAmt:SetText("Amount")
  ui.hdrAmt:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  ui.hdrHits = makeDashLabel(ui.table, "DM2StatsMenuBuildSetsHdrHits", 11, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.hdrHits:SetText("Hits")
  ui.hdrHits:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  ui.hdrShare = makeDashLabel(ui.table, "DM2StatsMenuBuildSetsHdrShare", 11, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.hdrShare:SetText("Share")
  ui.hdrShare:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  ui.hdrCrit = makeDashLabel(ui.table, "DM2StatsMenuBuildSetsHdrCrit", 11, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.hdrCrit:SetText("Crit")
  ui.hdrCrit:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  ui.hdrType = makeDashLabel(ui.table, "DM2StatsMenuBuildSetsHdrType", 11, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.hdrType:SetText("Type")
  ui.hdrType:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  ui.hdrDps = makeDashLabel(ui.table, "DM2StatsMenuBuildSetsHdrDps", 11, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.hdrDps:SetText("DPS")
  ui.hdrDps:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

  ui.cpPanel = WM:CreateControl("DM2StatsMenuBuildSetsCpPanelV5", ui.root, CT_CONTROL)
  local cbg = makeSectionFrame(ui.cpPanel, "DM2StatsMenuBuildSetsCpBGV5", true)
  cbg:SetAnchorFill(ui.cpPanel)
  ui.cpTitle = makeDashLabel(ui.cpPanel, "DM2StatsMenuBuildSetsCpTitleV6", 13, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.cpTitle:SetText("CHAMPION POINT IMPACT  ·  equipped | fit | parse impact")
  ui.cpNote = makeDashLabel(ui.cpPanel, "DM2StatsMenuBuildSetsCpNoteV6", 10, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.cpNote:SetMaxLineCount(1)
  ui.cpNote:SetText("Fit = parse-mix heuristic · Eligible % = damage share matching star · +DPS only from real A/B runs")
  for i = 1, BUILD_SET_CP_ROWS do
    local row = WM:CreateControl("DM2StatsMenuBuildSetsCpRowV6_" .. i, ui.cpPanel, CT_CONTROL)
    local fit = makeDashLabel(row, "DM2StatsMenuBuildSetsCpFitV6_" .. i, 11, 0.45, 0.92, 0.55, 1)
    -- Colored constellation chip (Combat / Fitness / Craft) left of name
    local tree = makeDashLabel(row, "DM2StatsMenuBuildSetsCpTreeV6_" .. i, 10, 0.91, 0.36, 0.36, 1)
    tree:SetDimensions(14, 14)
    local name = makeDashLabel(row, "DM2StatsMenuBuildSetsCpNameV6_" .. i, 12, THEME.textR, THEME.textG, THEME.textB, 1)
    local impact = makeDashLabel(row, "DM2StatsMenuBuildSetsCpImpactV6_" .. i, 11, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
    ui.cpRows[i] = { row = row, fit = fit, tree = tree, name = name, impact = impact }
  end

  for i = 1, BUILD_SET_PROC_ROWS do
    local row = WM:CreateControl("DM2StatsMenuBuildSetsRowV4_" .. i, ui.table, CT_CONTROL)
    local name = makeDashLabel(row, "DM2StatsMenuBuildSetsNameV4_" .. i, 13, THEME.textR, THEME.textG, THEME.textB, 1)
    local barBg = WM:CreateControl("DM2StatsMenuBuildSetsBarBgV4_" .. i, row, CT_BACKDROP)
    barBg:SetCenterColor(0.12, 0.12, 0.14, 0.55)
    barBg:SetEdgeColor(0, 0, 0, 0)
    local barFg = WM:CreateControl("DM2StatsMenuBuildSetsBarFgV4_" .. i, barBg, CT_BACKDROP)
    barFg:SetCenterColor(0.92, 0.78, 0.40, 0.9)
    barFg:SetEdgeColor(0, 0, 0, 0)
    barFg:SetAnchor(TOPLEFT, barBg, TOPLEFT, 0, 0)
    barFg:SetDimensions(2, 5)
    local amt = makeDashLabel(row, "DM2StatsMenuBuildSetsAmtV4_" .. i, 12, THEME.textR, THEME.textG, THEME.textB, 1)
    amt:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    local hits = makeDashLabel(row, "DM2StatsMenuBuildSetsHitsV4_" .. i, 12, THEME.textR, THEME.textG, THEME.textB, 1)
    hits:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    local share = makeDashLabel(row, "DM2StatsMenuBuildSetsShareV4_" .. i, 12, THEME.textR, THEME.textG, THEME.textB, 1)
    share:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    local crit = makeDashLabel(row, "DM2StatsMenuBuildSetsCritV4_" .. i, 12, THEME.textR, THEME.textG, THEME.textB, 1)
    crit:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    local kind = makeDashLabel(row, "DM2StatsMenuBuildSetsTypeV4_" .. i, 12, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
    kind:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    local dps = makeDashLabel(row, "DM2StatsMenuBuildSetsDpsV4_" .. i, 12, THEME.textR, THEME.textG, THEME.textB, 1)
    dps:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    ui.rows[i] = {
      row = row, name = name, barBg = barBg, barFg = barFg,
      amt = amt, hits = hits, share = share, crit = crit, kind = kind, dps = dps,
    }
  end
  ui.empty = makeDashLabel(ui.root, "DM2StatsMenuBuildSetsEmptyV4", 15, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.empty:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, 60)
  ui.empty:SetHidden(true)
  screen.procsUI = ui
  return ui
end

local function layoutProcsUI(ui, hostW, hostH)
  if not ui or not ui.root then return end
  local W = math.max(480, (hostW or 900) - 8)
  local H = math.max(400, (hostH or 700) - 8)
  ui.root:ClearAnchors()
  ui.root:SetAnchor(TOPLEFT, ui.panel, TOPLEFT, 8, 4)
  ui.root:SetDimensions(W, H)
  ui.title:SetWidth(W)
  ui.meta:SetWidth(W)
  ui.empty:SetWidth(W)

  local buildH = math.min(150, math.max(128, math.floor(H * 0.22)))
  -- CP panel taller; short single-line note so it never paints over first CP row
  local cpH = math.min(220, math.max(158, math.floor(H * 0.34)))
  ui.buildPanel:ClearAnchors()
  ui.buildPanel:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, 36)
  ui.buildPanel:SetDimensions(W, buildH)
  ui.buildTitle:ClearAnchors()
  ui.buildTitle:SetAnchor(TOPLEFT, ui.buildPanel, TOPLEFT, 10, 4)
  ui.buildTitle:SetWidth(W - 20)
  ui.buildProv:ClearAnchors()
  ui.buildProv:SetAnchor(TOPLEFT, ui.buildPanel, TOPLEFT, 10, 20)
  ui.buildProv:SetWidth(W - 20)

  ui.frontTitle:ClearAnchors()
  ui.frontTitle:SetAnchor(TOPLEFT, ui.buildPanel, TOPLEFT, 10, 38)
  ui.backTitle:ClearAnchors()
  ui.backTitle:SetAnchor(TOPLEFT, ui.buildPanel, TOPLEFT, 10, 78)
  for i = 1, 6 do
    local f = ui.barIcons.front[i]
    local b = ui.barIcons.back[i]
    if f and f.bg then
      f.bg:ClearAnchors()
      f.bg:SetAnchor(TOPLEFT, ui.buildPanel, TOPLEFT, 70 + (i - 1) * 34, 34)
    end
    if b and b.bg then
      b.bg:ClearAnchors()
      b.bg:SetAnchor(TOPLEFT, ui.buildPanel, TOPLEFT, 70 + (i - 1) * 34, 74)
    end
  end
  local lineX = math.min(W - 12, 70 + 6 * 34 + 16)
  local lineW = math.max(160, W - lineX - 12)
  for i = 1, 5 do
    local line = ui.buildLines[i]
    if line then
      line:ClearAnchors()
      line:SetAnchor(TOPLEFT, ui.buildPanel, TOPLEFT, lineX, 34 + (i - 1) * 18)
      line:SetWidth(lineW)
    end
  end

  local tableY = 36 + buildH + 6
  local tableH = H - tableY - cpH - 10
  if tableH < 120 then tableH = 120 end
  ui.table:ClearAnchors()
  ui.table:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, tableY)
  ui.table:SetDimensions(W, tableH)

  if ui.cpPanel then
    local cpY = tableY + tableH + 6
    ui.cpPanel:ClearAnchors()
    ui.cpPanel:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, cpY)
    ui.cpPanel:SetDimensions(W, cpH)
    if ui.cpTitle then
      ui.cpTitle:ClearAnchors()
      ui.cpTitle:SetAnchor(TOPLEFT, ui.cpPanel, TOPLEFT, 10, 4)
      ui.cpTitle:SetWidth(W - 20)
    end
    if ui.cpNote then
      ui.cpNote:ClearAnchors()
      ui.cpNote:SetAnchor(TOPLEFT, ui.cpPanel, TOPLEFT, 12, 18)
      ui.cpNote:SetWidth(W - 24)
      if ui.cpNote.SetMaxLineCount then ui.cpNote:SetMaxLineCount(1) end
      if ui.cpNote.SetWrapMode then
        ui.cpNote:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
      end
    end
    -- Gap under the one-line note so it cannot cover Warfare row 1
    local cpTop = 42
    local cpRowH = math.max(15, math.floor((cpH - cpTop - 4) / BUILD_SET_CP_ROWS))
    for i = 1, BUILD_SET_CP_ROWS do
      local r = ui.cpRows and ui.cpRows[i]
      if r then
        r.row:ClearAnchors()
        r.row:SetAnchor(TOPLEFT, ui.cpPanel, TOPLEFT, 10, cpTop + (i - 1) * cpRowH)
        r.row:SetDimensions(W - 20, cpRowH - 1)
        r.fit:ClearAnchors()
        r.fit:SetAnchor(LEFT, r.row, LEFT, 0, 0)
        r.fit:SetWidth(48)
        if r.tree then
          r.tree:ClearAnchors()
          r.tree:SetAnchor(LEFT, r.row, LEFT, 50, 0)
          r.tree:SetWidth(14)
        end
        local nW = math.max(110, math.floor((W - 20) * 0.26))
        r.name:ClearAnchors()
        r.name:SetAnchor(LEFT, r.row, LEFT, 68, 0)
        r.name:SetWidth(nW)
        r.name:SetMaxLineCount(1)
        r.impact:ClearAnchors()
        r.impact:SetAnchor(LEFT, r.row, LEFT, 72 + nW, 0)
        r.impact:SetWidth(math.max(160, W - 100 - nW))
        r.impact:SetMaxLineCount(1)
      end
    end
  end
  ui.setTitle:ClearAnchors()
  ui.setTitle:SetAnchor(TOPLEFT, ui.table, TOPLEFT, 10, 4)
  ui.setTitle:SetWidth(W - 20)
  ui.legend:ClearAnchors()
  ui.legend:SetAnchor(TOPLEFT, ui.table, TOPLEFT, 10, 20)
  ui.legend:SetWidth(W - 20)

  local pad, nameX = 10, 14
  -- Set/Proc names +30% vs prior (still truncating Perfected / buff notes)
  local nameW = math.min(520, math.max(280, math.floor(W * 0.58)))
  local prefs = { 68, 38, 46, 42, 42, 54 }
  local metricStart = nameX + nameW + 12
  local span = (W - pad) - metricStart
  local prefSum = 0
  for _, p in ipairs(prefs) do prefSum = prefSum + p end
  prefSum = prefSum + 6 * (#prefs - 1)
  local scale = span / math.max(1, prefSum)
  if scale > 1.35 then scale = 1.35 end
  if scale < 0.75 then scale = 0.75 end
  local widths, xs = {}, {}
  local x = metricStart
  for i, p in ipairs(prefs) do
    widths[i] = math.floor(p * scale)
    xs[i] = x
    x = x + widths[i] + 6
  end
  local function placeHdr(lbl, hx, hw)
    lbl:ClearAnchors()
    lbl:SetAnchor(TOPLEFT, ui.table, TOPLEFT, hx, 38)
    lbl:SetWidth(hw)
  end
  placeHdr(ui.hdrName, nameX, nameW)
  placeHdr(ui.hdrAmt, xs[1], widths[1])
  placeHdr(ui.hdrHits, xs[2], widths[2])
  placeHdr(ui.hdrShare, xs[3], widths[3])
  placeHdr(ui.hdrCrit, xs[4], widths[4])
  placeHdr(ui.hdrType, xs[5], widths[5])
  placeHdr(ui.hdrDps, xs[6], widths[6])

  local rowTop = 56
  local rowH = math.floor((tableH - rowTop - 6) / BUILD_SET_PROC_ROWS)
  if rowH < 24 then rowH = 24 end
  if rowH > 34 then rowH = 34 end
  for i = 1, BUILD_SET_PROC_ROWS do
    local r = ui.rows[i]
    if r then
      r.row:ClearAnchors()
      r.row:SetAnchor(TOPLEFT, ui.table, TOPLEFT, pad, rowTop + (i - 1) * rowH)
      r.row:SetDimensions(W - pad * 2, rowH - 2)
      r.name:ClearAnchors()
      r.name:SetAnchor(TOPLEFT, r.row, TOPLEFT, nameX - pad, 2)
      r.name:SetWidth(nameW)
      r.barBg:ClearAnchors()
      r.barBg:SetAnchor(BOTTOMLEFT, r.row, BOTTOMLEFT, nameX - pad, -2)
      r.barBg:SetDimensions(math.min(160, nameW), 4)
      local function place(lbl, cx, cw)
        lbl:ClearAnchors()
        lbl:SetAnchor(TOPLEFT, r.row, TOPLEFT, cx - pad, 4)
        lbl:SetWidth(cw)
      end
      place(r.amt, xs[1], widths[1])
      place(r.hits, xs[2], widths[2])
      place(r.share, xs[3], widths[3])
      place(r.crit, xs[4], widths[4])
      place(r.kind, xs[5], widths[5])
      place(r.dps, xs[6], widths[6])
    end
  end
end

local function refreshProcsUI(screen, session)
  local ui = createProcsUI(screen)
  if not ui then return end
  local hostW, hostH = layoutContentHost(screen)
  layoutProcsUI(ui, hostW, hostH)
  if not session then
    ui.meta:SetText("No fight selected")
    ui.empty:SetText("History is empty.")
    ui.empty:SetHidden(false)
    ui.table:SetHidden(true)
    if ui.buildPanel then ui.buildPanel:SetHidden(true) end
    if ui.cpPanel then ui.cpPanel:SetHidden(true) end
    return
  end
  ui.empty:SetHidden(true)
  ui.table:SetHidden(false)
  if ui.buildPanel then ui.buildPanel:SetHidden(false) end
  if ui.cpPanel then ui.cpPanel:SetHidden(false) end

  local snap = (type(session.playerStatsEnd) == "table") and session.playerStatsEnd
    or (type(session.playerStats) == "table") and session.playerStats
    or (type(session.playerStatsStart) == "table") and session.playerStatsStart
    or nil
  local phase = (session.playerStats or session.playerStatsEnd) and "end"
    or session.playerStatsStart and "start" or "live"
  if not snap then snap = capturePlayerStats(); phase = "live" end

  local profile = getActiveContentProfile()
  ui.meta:SetText(formatStatProvenance(session, snap, phase) .. "  ·  " .. formatProfileBadge(profile))
  local build = session.build or session.buildEnd or session.buildStart
  if ui.buildProv then
    if build and build.fingerprint then
      ui.buildProv:SetText(string.format(
        "Build ID %s  ·  %s  ·  %s",
        build.fingerprint,
        displayName(build.fingerprintLabel or "", 48),
        formatStatProvenance(session, snap, phase)
      ))
    else
      ui.buildProv:SetText(formatStatProvenance(session, snap, phase) .. "  ·  bars/sets from parse snapshot")
    end
  end

  local frontBar = collectBarSlots(session, "Front")
  local backBar = collectBarSlots(session, "Back")
  refreshBarIcons(ui.barIcons.front, frontBar)
  refreshBarIcons(ui.barIcons.back, backBar)

  local sets = {}
  if type(session.equippedSets) == "table" then
    for _, n in ipairs(session.equippedSets) do sets[#sets + 1] = tostring(n) end
  end
  local mundus = session.mundus or (snap and snap.mundus) or "—"
  local attrs = snap.attributes or {}
  local c = snap.buffed or {}
  local food = (build and build.food) or session.food or captureActiveFood() or "—"
  local gold = "|cEAC67A"
  local function goldLead(label, rest)
    return string.format("%s%s|r  %s", gold, label, rest or "")
  end
  if ui.buildLines[1] then
    ui.buildLines[1]:SetText(goldLead("Sets", (#sets > 0) and table.concat(sets, " · ") or "(none captured)"))
  end
  if ui.buildLines[2] then
    ui.buildLines[2]:SetText(goldLead(
      "Mundus / Food",
      string.format("%s  ·  %s", tostring(mundus), displayName(tostring(food), 48))
    ))
  end
  if ui.buildLines[3] then
    ui.buildLines[3]:SetText(goldLead(
      "Attributes",
      string.format("Magicka %s · Health %s · Stamina %s",
        tostring(attrs.magicka or "—"),
        tostring(attrs.health or "—"),
        tostring(attrs.stamina or "—"))
    ))
  end
  if ui.buildLines[4] then
    ui.buildLines[4]:SetText(goldLead(
      "Sheet",
      string.format("Crit %0.1f%% · Pen phys %s · Pen spell %s",
        (tonumber(c.critChance) or critFractionFromRatings(c.critWeapon, c.critSpell) or 0) * 100,
        fmtInt(c.penPhysical or 0),
        fmtInt(c.penSpell or 0))
    ))
  end
  if ui.buildLines[5] then
    ui.buildLines[5]:SetText(goldLead(
      "Power",
      string.format("Weapon %s · Spell %s  ·  Magicka %s · Stamina %s  ·  Food bonuses in Sheet vs Base",
        fmtInt(c.weaponDamage or c.power or 0),
        fmtInt(c.spellDamage or 0),
        fmtInt(c.magicka or 0),
        fmtInt(c.stamina or 0))
    ))
  end

  -- Champion Point impact: eligible % + Path B A/B marginal when history allows
  local syn = buildBuildSynergy(session)
  local coach = getSessionCoach(session) or buildCoachAnalysis(session, syn, buildParseDiagnosis(session), profile)
  setSessionCoach(session, coach)
  -- Coach already applies A/B marginals onto its syn; re-apply to local syn for display
  if coach and coach.cpAbPairs then
    applyCpAbMarginals(syn, coach.cpAbPairs)
  end
  local cps = (syn and syn.cps) or {}
  if ui.cpNote then
    local abN = (coach and coach.cpAbPairs and #coach.cpAbPairs) or 0
    local margN = 0
    for _, c in ipairs(cps) do
      if c.marginalDps ~= nil then margN = margN + 1 end
    end
    if margN > 0 then
      ui.cpNote:SetText(string.format(
        "Fit = mix heuristic · Eligible %% = category share · %d star(s) show A/B ΔDPS from history (same bars/sets/Mundus)",
        margN
      ))
    elseif abN > 0 then
      ui.cpNote:SetText(string.format(
        "Fit = mix heuristic · Eligible %% = category share · %d history A/B pair(s) — open Insights: Build",
        abN
      ))
    else
      ui.cpNote:SetText(
        "Warfare Fit = mix vs this parse · Fitness is survivability (dummy N/A — dummy does not hit back) · A/B ΔDPS after two dummies + one CP swap"
      )
    end
  end
  local treeColors = {
    combat = { 0.91, 0.36, 0.36 },
    fitness = { 0.36, 0.61, 0.84 },
    craft = { 0.44, 0.75, 0.45 },
    unknown = { 0.67, 0.67, 0.67 },
  }
  local treeGlyph = { combat = "●", fitness = "●", craft = "●", unknown = "·" }
  for i = 1, BUILD_SET_CP_ROWS do
    local r = ui.cpRows and ui.cpRows[i]
    local cp = cps[i]
    if r then
      if cp then
        r.row:SetHidden(false)
        r.fit:SetText(cp.fitLabel or "?")
        local fr, fg, fb, fa = fitBadgeColor(cp.fitKey)
        r.fit:SetColor(fr, fg, fb, fa or 1)
        local cKey = cp.constellation or "unknown"
        if r.tree then
          local col = treeColors[cKey] or treeColors.unknown
          r.tree:SetText(treeGlyph[cKey] or "●")
          r.tree:SetColor(col[1], col[2], col[3], 1)
          r.tree:SetHidden(false)
        end
        r.name:SetText(formatAbilityDisplay(cp.name, cp.id, 36))
        local impactTxt
        if cp.fitKey == "na" or cp.fitKey == "surv" then
          impactTxt = string.format("#%s  %s", cp.rankTxt or "—", cp.impact or cp.eligibleNote or "")
        elseif cp.marginalDps ~= nil then
          -- Plain text only — color chips + truncate made console hide this line
          impactTxt = string.format(
            "#%s Eligible %s · A/B %s",
            cp.rankTxt or tostring(i),
            fmtPct(cp.eligiblePct or 0),
            fmtDpsDelta(cp.marginalDps)
          )
        else
          impactTxt = string.format(
            "#%s Eligible %s · %s",
            cp.rankTxt or tostring(i),
            fmtPct(cp.eligiblePct or 0),
            cp.eligibleNote or "category"
          )
        end
        r.impact:SetText(displayNamePlain(impactTxt, 72))
      else
        r.row:SetHidden(i ~= 1 or #cps > 0)
        if i == 1 and #cps == 0 then
          r.row:SetHidden(false)
          r.fit:SetText("")
          if r.tree then r.tree:SetHidden(true) end
          r.name:SetText("(no champion bar stars)")
          r.impact:SetText("Open Champion bar once, then reload if empty")
        end
      end
    end
  end

  local rows = buildProcModelRows(session, BUILD_SET_PROC_ROWS)
  -- Enrich set names with buff-mediated notes from coach when no direct row
  local coachByName = {}
  for _, si in ipairs(coach.setImpact or {}) do
    coachByName[string.lower(tostring(si.name or ""))] = si
  end
  if ui.setTitle then
    ui.setTitle:SetText(string.format("SET / PROC CONTRIBUTION  ·  %d sources · total %s",
      math.max(#rows, #(coach.setImpact or {})), fmtInt(session.totalDamage)))
  end
  if ui.legend then
    ui.legend:SetText("Direct share = observed set/proc damage. Buff-mediated uptime when name matches. Marginal set value: Insufficient Data.")
  end
  for i = 1, BUILD_SET_PROC_ROWS do
    local r = ui.rows[i]
    local p = rows[i]
    -- Fall back to equipped-only coach rows if fewer direct procs
    if not p and coach.setImpact and coach.setImpact[i] then
      local si = coach.setImpact[i]
      p = {
        name = si.name,
        amountTxt = fmtInt(si.directDmg or 0),
        hitsTxt = "—",
        shareTxt = fmtPct(si.directShare or 0),
        critTxt = "—",
        kindTxt = (si.directDmg or 0) > 0 and "Direct" or "No proc",
        dpsTxt = fmtDps(si.directDps or 0),
        share = si.directShare or 0,
      }
      if si.buffNotes and #si.buffNotes > 0 then
        p.name = string.format("%s  [%s]", si.name, table.concat(si.buffNotes, ", "))
      elseif si.note then
        p.name = string.format("%s  (%s)", si.name, "buff/unmeasurable")
      end
    elseif p and coachByName[string.lower(tostring(p.name or ""))] then
      local si = coachByName[string.lower(tostring(p.name or ""))]
      if si.buffNotes and #si.buffNotes > 0 then
        p = {
          name = string.format("%s  [%s]", p.name, table.concat(si.buffNotes, ", ")),
          amountTxt = p.amountTxt,
          hitsTxt = p.hitsTxt,
          shareTxt = p.shareTxt,
          critTxt = p.critTxt,
          kindTxt = p.kindTxt,
          dpsTxt = p.dpsTxt,
          share = p.share,
        }
      end
    end
    if r then
      if p then
        r.row:SetHidden(false)
        r.name:SetText(displayName(p.name or "?", 42))
        r.amt:SetText(p.amountTxt or "")
        r.hits:SetText(p.hitsTxt or "")
        r.share:SetText(p.shareTxt or "")
        r.crit:SetText(p.critTxt or "")
        r.kind:SetText(p.kindTxt or "")
        r.dps:SetText(p.dpsTxt or "")
        local share = tonumber(p.share) or 0
        local bgW = r.barBg:GetWidth() or 140
        if bgW < 10 then bgW = 140 end
        r.barFg:SetDimensions(math.max(2, math.floor(bgW * math.min(1, share))), 4)
      else
        r.row:SetHidden(true)
      end
    end
  end
end

---------------------------------------------------------------------
-- Weave = overlay Weave Analysis (summary + per-skill + DoT; lazy)
---------------------------------------------------------------------
local WEAVE_SKILL_ROWS = 10
local WEAVE_DOT_ROWS = 8

local function createWeaveUI(screen)
  if screen.weaveUI and not screen.weaveUI._v381 then screen.weaveUI = nil end
  if screen.weaveUI then return screen.weaveUI end
  ensureContentHost(screen)
  local panel = screen.contentPanels and screen.contentPanels.weave
  if not panel then return nil end

  local ui = {
    panel = panel,
    kpi = {},
    skillRows = {},
    dotRows = {},
    _v381 = true,
  }

  ui.root = WM:CreateControl("DM2StatsMenuWeaveRootV8", panel, CT_CONTROL)
  ui.root:SetAnchor(TOPLEFT, panel, TOPLEFT, 8, 4)
  stampForeground(ui.root, 55)

  ui.title = makeDashLabel(ui.root, "DM2StatsMenuWeaveTitle", 16, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.title:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, 0)
  ui.title:SetText("WEAVE ANALYSIS")

  ui.meta = makeDashLabel(ui.root, "DM2StatsMenuWeaveMeta", 13, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.meta:SetAnchor(TOPLEFT, ui.title, BOTTOMLEFT, 0, 2)

  -- Summary KPI strip (6 tiles)
  ui.sumPanel = WM:CreateControl("DM2StatsMenuWeaveSumPanel", ui.root, CT_CONTROL)
  ui.sumPanel:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, 44)
  local sumBg = makeSectionFrame(ui.sumPanel, "DM2StatsMenuWeaveSumBG", true)
  sumBg:SetAnchorFill(ui.sumPanel)
  local kpiDefs = {
    { key = "success", label = "Weave Success" },
    { key = "good", label = "Good" },
    { key = "late", label = "Late" },
    { key = "missed", label = "Missed" },
    { key = "fast", label = "Too Fast" },
    { key = "la", label = "LA Hits" },
    { key = "presses", label = "Skill Presses" },
    { key = "swaps", label = "Bar Swaps" },
  }
  ui.kpiDefs = kpiDefs
  for _, def in ipairs(kpiDefs) do
    local block = WM:CreateControl("DM2StatsMenuWeaveKpi_" .. def.key, ui.sumPanel, CT_CONTROL)
    local bg = makeSectionFrame(block, "DM2StatsMenuWeaveKpiBG_" .. def.key, false)
    bg:SetAnchorFill(block)
    -- Label on top, value below — label slightly higher so header block feels tighter
    local label = makeDashLabel(block, "DM2StatsMenuWeaveKpiLab_" .. def.key, 11, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
    label:SetAnchor(TOPLEFT, block, TOPLEFT, 8, 2)
    label:SetText(def.label)
    local value = makeDashLabel(block, "DM2StatsMenuWeaveKpiVal_" .. def.key, 18, THEME.textR, THEME.textG, THEME.textB, 1)
    value:SetAnchor(TOPLEFT, block, TOPLEFT, 8, 16)
    ui.kpi[def.key] = { block = block, value = value, label = label }
  end

  -- Per-skill weave table
  ui.skillPanel = WM:CreateControl("DM2StatsMenuWeaveSkillPanel", ui.root, CT_CONTROL)
  local skBg = makeSectionFrame(ui.skillPanel, "DM2StatsMenuWeaveSkillBG", true)
  skBg:SetAnchorFill(ui.skillPanel)
  ui.skillTitle = makeDashLabel(ui.skillPanel, "DM2StatsMenuWeaveSkillTitle", 14, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.skillTitle:SetAnchor(TOPLEFT, ui.skillPanel, TOPLEFT, 10, 6)
  ui.skillTitle:SetText("PER-SKILL WEAVE")
  ui.skillLegend = makeDashLabel(ui.skillPanel, "DM2StatsMenuWeaveSkillLegend", 11, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.skillLegend:SetAnchor(TOPLEFT, ui.skillTitle, BOTTOMLEFT, 0, 1)
  ui.skillLegend:SetText("|c88DDAAF|r Front   |c88AADDB|r Back   ·  Good / Late / Missed / Fast / Casts")
  -- Tip sits above the column headers with reserved vertical room (no merge into skill list).
  ui.tipLine = makeDashLabel(ui.skillPanel, "DM2StatsMenuWeaveTip", 12, 0.65, 0.90, 1.0, 1)
  ui.tipLine:SetAnchor(TOPLEFT, ui.skillLegend, BOTTOMLEFT, 0, 4)
  ui.tipLine:SetMaxLineCount(2)

  ui.hdrName = makeDashLabel(ui.skillPanel, "DM2StatsMenuWeaveHdrName", 11, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.hdrName:SetText("Skill")
  ui.hdrGood = makeDashLabel(ui.skillPanel, "DM2StatsMenuWeaveHdrGood", 11, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.hdrGood:SetText("Good%")
  ui.hdrGood:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  ui.hdrG = makeDashLabel(ui.skillPanel, "DM2StatsMenuWeaveHdrG", 11, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.hdrG:SetText("Good")
  ui.hdrG:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  ui.hdrL = makeDashLabel(ui.skillPanel, "DM2StatsMenuWeaveHdrL", 11, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.hdrL:SetText("Late")
  ui.hdrL:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  ui.hdrM = makeDashLabel(ui.skillPanel, "DM2StatsMenuWeaveHdrM", 11, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.hdrM:SetText("Miss")
  ui.hdrM:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  ui.hdrF = makeDashLabel(ui.skillPanel, "DM2StatsMenuWeaveHdrF", 11, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.hdrF:SetText("Fast")
  ui.hdrF:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  ui.hdrN = makeDashLabel(ui.skillPanel, "DM2StatsMenuWeaveHdrN", 11, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.hdrN:SetText("Casts")
  ui.hdrN:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

  for i = 1, WEAVE_SKILL_ROWS do
    local row = WM:CreateControl("DM2StatsMenuWeaveSkRow" .. i, ui.skillPanel, CT_CONTROL)
    local chip = makeDashLabel(row, "DM2StatsMenuWeaveSkChip" .. i, 11, THEME.frontR, THEME.frontG, THEME.frontB, 1)
    chip:SetDimensions(12, 14)
    local icon = WM:CreateControl("DM2StatsMenuWeaveSkIcon" .. i, row, CT_TEXTURE)
    icon:SetDimensions(22, 22)
    stampForeground(icon, 110)
    local name = makeDashLabel(row, "DM2StatsMenuWeaveSkName" .. i, 13, THEME.textR, THEME.textG, THEME.textB, 1)
    local barBg = WM:CreateControl("DM2StatsMenuWeaveSkBarBg" .. i, row, CT_BACKDROP)
    barBg:SetCenterColor(0.12, 0.12, 0.14, 0.55)
    barBg:SetEdgeColor(0, 0, 0, 0)
    barBg:SetDimensions(100, 4)
    local barFg = WM:CreateControl("DM2StatsMenuWeaveSkBarFg" .. i, barBg, CT_BACKDROP)
    barFg:SetCenterColor(0.45, 0.88, 0.48, 0.9)
    barFg:SetEdgeColor(0, 0, 0, 0)
    barFg:SetAnchor(TOPLEFT, barBg, TOPLEFT, 0, 0)
    barFg:SetDimensions(2, 4)
    local good = makeDashLabel(row, "DM2StatsMenuWeaveSkGood" .. i, 13, THEME.textR, THEME.textG, THEME.textB, 1)
    good:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    local g = makeDashLabel(row, "DM2StatsMenuWeaveSkG" .. i, 13, THEME.textR, THEME.textG, THEME.textB, 1)
    g:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    local l = makeDashLabel(row, "DM2StatsMenuWeaveSkL" .. i, 13, THEME.textR, THEME.textG, THEME.textB, 1)
    l:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    local m = makeDashLabel(row, "DM2StatsMenuWeaveSkM" .. i, 13, THEME.textR, THEME.textG, THEME.textB, 1)
    m:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    local f = makeDashLabel(row, "DM2StatsMenuWeaveSkF" .. i, 13, THEME.textR, THEME.textG, THEME.textB, 1)
    f:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    local n = makeDashLabel(row, "DM2StatsMenuWeaveSkN" .. i, 13, THEME.textR, THEME.textG, THEME.textB, 1)
    n:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    ui.skillRows[i] = {
      row = row, chip = chip, icon = icon, name = name,
      barBg = barBg, barFg = barFg,
      good = good, g = g, l = l, m = m, f = f, n = n,
    }
  end

  -- DoT uptime panel
  ui.dotPanel = WM:CreateControl("DM2StatsMenuWeaveDotPanel", ui.root, CT_CONTROL)
  local dotBg = makeSectionFrame(ui.dotPanel, "DM2StatsMenuWeaveDotBG", true)
  dotBg:SetAnchorFill(ui.dotPanel)
  ui.dotTitle = makeDashLabel(ui.dotPanel, "DM2StatsMenuWeaveDotTitle", 14, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.dotTitle:SetAnchor(TOPLEFT, ui.dotPanel, TOPLEFT, 10, 6)
  ui.dotTitle:SetText("DOT UPTIME (worst maintainable first)")
  ui.dotHelp = makeDashLabel(ui.dotPanel, "DM2StatsMenuWeaveDotHelp", 11, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.dotHelp:SetAnchor(TOPLEFT, ui.dotTitle, BOTTOMLEFT, 0, 1)
  ui.dotHelp:SetText("Uptime from tick gaps · long gaps shown when Phase 3 data present · enchant/status not skill-refresh")
  for i = 1, WEAVE_DOT_ROWS do
    local row = WM:CreateControl("DM2StatsMenuWeaveDotRow" .. i, ui.dotPanel, CT_CONTROL)
    local icon = WM:CreateControl("DM2StatsMenuWeaveDotIcon" .. i, row, CT_TEXTURE)
    icon:SetDimensions(22, 22)
    stampForeground(icon, 110)
    local name = makeDashLabel(row, "DM2StatsMenuWeaveDotName" .. i, 13, THEME.textR, THEME.textG, THEME.textB, 1)
    local sub = makeDashLabel(row, "DM2StatsMenuWeaveDotSub" .. i, 12, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
    local barBg = WM:CreateControl("DM2StatsMenuWeaveDotBarBg" .. i, row, CT_BACKDROP)
    barBg:SetCenterColor(0.12, 0.12, 0.14, 0.55)
    barBg:SetEdgeColor(0, 0, 0, 0)
    barBg:SetDimensions(160, 5)
    local barFg = WM:CreateControl("DM2StatsMenuWeaveDotBarFg" .. i, barBg, CT_BACKDROP)
    barFg:SetCenterColor(0.92, 0.72, 0.32, 0.9)
    barFg:SetEdgeColor(0, 0, 0, 0)
    barFg:SetAnchor(TOPLEFT, barBg, TOPLEFT, 0, 0)
    barFg:SetDimensions(2, 5)
    ui.dotRows[i] = { row = row, icon = icon, name = name, sub = sub, barBg = barBg, barFg = barFg }
  end

  ui.empty = makeDashLabel(ui.root, "DM2StatsMenuWeaveEmpty", 15, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.empty:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, 50)
  ui.empty:SetHidden(true)

  screen.weaveUI = ui
  return ui
end

local function layoutWeaveUI(ui, hostW, hostH)
  if not ui or not ui.root then return end
  local W = math.max(480, (hostW or 900) - 8)
  local H = math.max(400, (hostH or 700) - 8)
  ui.root:ClearAnchors()
  ui.root:SetAnchor(TOPLEFT, ui.panel, TOPLEFT, 8, 4)
  ui.root:SetDimensions(W, H)
  ui.title:SetWidth(W)
  ui.meta:SetWidth(W)
  ui.empty:SetWidth(W)

  local sumH = 96
  ui.sumPanel:ClearAnchors()
  ui.sumPanel:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, 36)
  ui.sumPanel:SetDimensions(W, sumH)
  local cols, rows = 4, 2
  local gap = 6
  local pad = 8
  local cellW = math.floor((W - pad * 2 - gap * (cols - 1)) / cols)
  local cellH = math.floor((sumH - pad * 2 - gap) / rows)
  for i, def in ipairs(ui.kpiDefs or {}) do
    local cell = ui.kpi[def.key]
    if cell and cell.block then
      local col = (i - 1) % cols
      local row = math.floor((i - 1) / cols)
      cell.block:ClearAnchors()
      cell.block:SetDimensions(cellW, cellH)
      cell.block:SetAnchor(TOPLEFT, ui.sumPanel, TOPLEFT, pad + col * (cellW + gap), pad + row * (cellH + gap))
      if cell.value then cell.value:SetWidth(cellW - 12) end
      if cell.label then cell.label:SetWidth(cellW - 12) end
    end
  end

  local midY = 36 + sumH + 8
  local skillH = math.floor((H - midY - 6) * 0.56)
  if skillH < 180 then skillH = 180 end
  local dotH = H - midY - skillH - 6
  if dotH < 120 then
    skillH = H - midY - 126
    dotH = 120
  end

  ui.skillPanel:ClearAnchors()
  ui.skillPanel:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, midY)
  ui.skillPanel:SetDimensions(W, skillH)
  ui.skillTitle:SetWidth(W - 20)
  ui.skillLegend:SetWidth(W - 20)
  if ui.tipLine then ui.tipLine:SetWidth(W - 20) end

  -- Wider cols for word headers Good/Late/Miss/Fast/Casts
  local nameX = 44
  local nameW = math.min(250, math.max(160, math.floor(W * 0.26)))
  local gap = 6
  local metricStart = nameX + nameW + 10
  local prefs = { 60, 50, 50, 50, 50, 52 }
  local prefSum = 0
  for _, pw in ipairs(prefs) do prefSum = prefSum + pw end
  prefSum = prefSum + gap * (#prefs - 1)
  local span = (W - 14) - metricStart
  local scale = span / math.max(1, prefSum)
  if scale > 1.4 then scale = 1.4 end
  if scale < 0.8 then scale = 0.8 end
  local widths, xs = {}, {}
  local x = metricStart
  for i, pw in ipairs(prefs) do
    widths[i] = math.floor(pw * scale)
    xs[i] = x
    x = x + widths[i] + gap
  end
  local xGood, xG, xL, xM, xF, xN = xs[1], xs[2], xs[3], xs[4], xs[5], xs[6]
  local nW, gW, lW, mW, fW, nnW = widths[1], widths[2], widths[3], widths[4], widths[5], widths[6]

  -- Header/list sit below title + legend + tip (tip was colliding with first rows).
  local hdrY = 72
  local rowTop = 90
  local function placeHdr(lbl, hx, hw)
    lbl:ClearAnchors()
    lbl:SetAnchor(TOPLEFT, ui.skillPanel, TOPLEFT, hx, hdrY)
    lbl:SetWidth(hw)
  end
  placeHdr(ui.hdrName, nameX, nameW)
  placeHdr(ui.hdrGood, xGood, nW)
  placeHdr(ui.hdrG, xG, gW)
  placeHdr(ui.hdrL, xL, lW)
  placeHdr(ui.hdrM, xM, mW)
  placeHdr(ui.hdrF, xF, fW)
  placeHdr(ui.hdrN, xN, nnW)

  local rowH = math.floor((skillH - rowTop - 6) / WEAVE_SKILL_ROWS)
  if rowH < 24 then rowH = 24 end
  if rowH > 30 then rowH = 30 end
  for i = 1, WEAVE_SKILL_ROWS do
    local r = ui.skillRows[i]
    if r then
      r.row:ClearAnchors()
      r.row:SetAnchor(TOPLEFT, ui.skillPanel, TOPLEFT, 10, rowTop + (i - 1) * rowH)
      r.row:SetDimensions(W - 20, rowH - 2)
      r.chip:ClearAnchors()
      r.chip:SetAnchor(LEFT, r.row, LEFT, 0, 0)
      r.icon:ClearAnchors()
      r.icon:SetAnchor(LEFT, r.row, LEFT, 14, 0)
      r.name:ClearAnchors()
      r.name:SetAnchor(TOPLEFT, r.row, TOPLEFT, nameX - 10, 2)
      r.name:SetWidth(nameW)
      r.name:SetMaxLineCount(1)
      r.barBg:ClearAnchors()
      r.barBg:SetAnchor(BOTTOMLEFT, r.row, BOTTOMLEFT, nameX - 10, -2)
      r.barBg:SetDimensions(math.min(120, nameW), 4)
      local function place(lbl, cx, cw)
        lbl:ClearAnchors()
        lbl:SetAnchor(TOPLEFT, r.row, TOPLEFT, cx - 10, 4)
        lbl:SetWidth(cw)
      end
      place(r.good, xGood, nW)
      place(r.g, xG, gW)
      place(r.l, xL, lW)
      place(r.m, xM, mW)
      place(r.f, xF, fW)
      place(r.n, xN, nnW)
    end
  end

  ui.dotPanel:ClearAnchors()
  ui.dotPanel:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, midY + skillH + 6)
  ui.dotPanel:SetDimensions(W, dotH)
  ui.dotTitle:SetWidth(W - 20)
  ui.dotHelp:SetWidth(W - 20)
  local dTop = 36
  local dH = math.floor((dotH - dTop - 4) / WEAVE_DOT_ROWS)
  if dH < 22 then dH = 22 end
  if dH > 28 then dH = 28 end
  -- Name left; longer gap/uptime text; bars shifted ~20% right
  local nameColW = math.min(220, math.max(140, math.floor(W * 0.22)))
  local subColW = math.min(380, math.max(200, math.floor(W * 0.38)))
  local barColW = math.min(180, math.max(90, math.floor(W * 0.16)))
  local barX = 28 + nameColW + subColW + math.floor(W * 0.04) -- ~20% more gap before bar
  for i = 1, WEAVE_DOT_ROWS do
    local r = ui.dotRows[i]
    if r then
      r.row:ClearAnchors()
      r.row:SetAnchor(TOPLEFT, ui.dotPanel, TOPLEFT, 10, dTop + (i - 1) * dH)
      r.row:SetDimensions(W - 20, dH - 2)
      r.icon:ClearAnchors()
      r.icon:SetAnchor(LEFT, r.row, LEFT, 0, 0)
      r.name:ClearAnchors()
      r.name:SetAnchor(TOPLEFT, r.row, TOPLEFT, 28, 2)
      r.name:SetWidth(nameColW)
      r.name:SetMaxLineCount(1)
      r.sub:ClearAnchors()
      r.sub:SetAnchor(TOPLEFT, r.row, TOPLEFT, 28 + nameColW + 10, 2)
      r.sub:SetWidth(subColW)
      r.sub:SetMaxLineCount(1)
      r.barBg:ClearAnchors()
      r.barBg:SetAnchor(TOPLEFT, r.row, TOPLEFT, barX, math.floor((dH - 8) / 2))
      r.barBg:SetDimensions(barColW, 8)
    end
  end
end

local function refreshWeaveUI(screen, session)
  local ui = createWeaveUI(screen)
  if not ui then return end
  local hostW, hostH = layoutContentHost(screen)
  layoutWeaveUI(ui, hostW, hostH)
  if session then ensurePhase3Summary(session) end

  if not session then
    ui.meta:SetText("No fight selected")
    ui.empty:SetText("History is empty.")
    ui.empty:SetHidden(false)
    ui.sumPanel:SetHidden(true)
    ui.skillPanel:SetHidden(true)
    ui.dotPanel:SetHidden(true)
    return
  end
  ui.empty:SetHidden(true)
  ui.sumPanel:SetHidden(false)
  ui.skillPanel:SetHidden(false)
  ui.dotPanel:SetHidden(false)

  local w = type(session.weave) == "table" and session.weave or {}
  local good = tonumber(w.onTimeCount) or 0
  local late = tonumber(w.lateCount) or 0
  local missed = tonumber(w.missedCount) or 0
  local tooFast = tonumber(w.tooFastCount) or 0
  local success = getWeaveSuccessRatio(session)
  ui.meta:SetText(string.format(
    "%s  ·  %s  ·  overall weave %s",
    truncateText(session.lastTargetName or "fight", 28),
    fmtDur(session.durationMs),
    fmtPct(success)
  ))

  local kpiVals = {
    success = fmtPct(success),
    good = tostring(good),
    late = tostring(late),
    missed = tostring(missed),
    fast = tostring(tooFast),
    la = tostring(sessionLaHits(session)),
    presses = tostring(tonumber(w.inputSkillPresses) or tonumber(w.skillEventCount) or 0),
    swaps = tostring(tonumber(w.barSwapCount) or 0),
  }
  for key, val in pairs(kpiVals) do
    local cell = ui.kpi[key]
    if cell and cell.value then cell.value:SetText(val) end
  end
  if ui.tipLine then
    local tips = buildPatternInsights(session)
    ui.tipLine:SetText(tips[1] or "")
  end

  local skillRows = buildPerSkillWeaveModel(session, WEAVE_SKILL_ROWS)
  for i = 1, WEAVE_SKILL_ROWS do
    local r = ui.skillRows[i]
    local item = skillRows[i]
    if r then
      if item then
        r.row:SetHidden(false)
        r.name:SetText(item.name or "?")
        r.good:SetText(item.goodTxt or "")
        r.g:SetText(item.gTxt or "")
        r.l:SetText(item.lTxt or "")
        r.m:SetText(item.mTxt or "")
        r.f:SetText(item.fTxt or "")
        r.n:SetText(item.nTxt or "")
        local chip = barChipLabel(item.bar)
        r.chip:SetText(chip)
        local cr, cg, cb, ca = barChipColor(item.bar)
        r.chip:SetColor(cr, cg, cb, ca)
        r.chip:SetHidden(chip == "")
        if item.icon then
          r.icon:SetTexture(item.icon)
          r.icon:SetHidden(false)
          r.icon:SetColor(1, 1, 1, 1)
        else
          r.icon:SetHidden(true)
        end
        local share = tonumber(item.share) or 0
        local bgW = r.barBg:GetWidth() or 100
        if bgW < 10 then bgW = 100 end
        r.barFg:SetDimensions(math.max(2, math.floor(bgW * math.min(1, share))), 4)
      else
        r.row:SetHidden(i ~= 1 or #skillRows > 0)
        if i == 1 and #skillRows == 0 then
          r.row:SetHidden(false)
          r.name:SetText("No per-skill weave samples (need timeline data).")
          r.good:SetText("")
          r.g:SetText("")
          r.l:SetText("")
          r.m:SetText("")
          r.f:SetText("")
          r.n:SetText("")
          r.chip:SetHidden(true)
          r.icon:SetHidden(true)
          r.barFg:SetDimensions(2, 4)
        end
      end
    end
  end

  local dots = buildDotUptimeModel(session, WEAVE_DOT_ROWS)
  for i = 1, WEAVE_DOT_ROWS do
    local r = ui.dotRows[i]
    local item = dots[i]
    if r then
      if item then
        r.row:SetHidden(false)
        r.name:SetText(item.name or "?")
        r.sub:SetText(item.sub or "")
        if item.icon then
          r.icon:SetTexture(item.icon)
          r.icon:SetHidden(false)
          r.icon:SetColor(1, 1, 1, 1)
        else
          r.icon:SetHidden(true)
        end
        local share = tonumber(item.share) or 0
        local bgW = r.barBg:GetWidth() or 160
        if bgW < 10 then bgW = 160 end
        local ratio = math.min(1, share)
        r.barFg:SetDimensions(math.max(2, math.floor(bgW * ratio)), 5)
        if ratio < 0.5 then
          r.barFg:SetCenterColor(0.88, 0.38, 0.30, 0.9)
        elseif ratio < 0.8 then
          r.barFg:SetCenterColor(0.92, 0.72, 0.32, 0.9)
        else
          r.barFg:SetCenterColor(0.45, 0.88, 0.48, 0.9)
        end
      else
        r.row:SetHidden(i ~= 1 or #dots > 0)
        if i == 1 and #dots == 0 then
          r.row:SetHidden(false)
          r.name:SetText("No DoT tick data for this fight.")
          r.sub:SetText("")
          r.icon:SetHidden(true)
          r.barFg:SetDimensions(2, 5)
        end
      end
    end
  end
end

---------------------------------------------------------------------
-- Gear — bars + sets strip + worn table (slot icon | slot | item | enchant)
---------------------------------------------------------------------
local GEAR_SET_LINES = 6
local GEAR_WORN_ROWS = 14

-- ESO character-window gearslot silhouettes (console-safe empty-slot art).
local GEAR_SLOT_ICON = {
  Head      = "/esoui/art/characterwindow/gearslot_head.dds",
  Shoulders = "/esoui/art/characterwindow/gearslot_shoulders.dds",
  Chest     = "/esoui/art/characterwindow/gearslot_chest.dds",
  Hands     = "/esoui/art/characterwindow/gearslot_hands.dds",
  Waist     = "/esoui/art/characterwindow/gearslot_belt.dds",
  Legs      = "/esoui/art/characterwindow/gearslot_legs.dds",
  Feet      = "/esoui/art/characterwindow/gearslot_feet.dds",
  Neck      = "/esoui/art/characterwindow/gearslot_neck.dds",
  ["Ring 1"] = "/esoui/art/characterwindow/gearslot_ring.dds",
  ["Ring 2"] = "/esoui/art/characterwindow/gearslot_ring.dds",
  ["Front MH"] = "/esoui/art/characterwindow/gearslot_mainhand.dds",
  ["Front OH"] = "/esoui/art/characterwindow/gearslot_offhand.dds",
  ["Back MH"]  = "/esoui/art/characterwindow/gearslot_mainhand.dds",
  ["Back OH"]  = "/esoui/art/characterwindow/gearslot_offhand.dds",
}

-- Full enchant text (matches overlay extractEnchantText — effect numbers, not just type name).
local function extractEnchantTextLocal(itemLink)
  if not itemLink or itemLink == "" then return "—" end
  if type(GetItemLinkEnchantDescription) == "function" then
    local ok, desc = pcall(GetItemLinkEnchantDescription, itemLink)
    if ok and desc and desc ~= "" then
      desc = stripColorLocal(desc)
      if type(zo_strformat) == "function" then
        local okF, f = pcall(zo_strformat, "<<1>>", desc)
        if okF and f and f ~= "" then desc = f end
      end
      desc = desc:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
      if desc ~= "" and desc ~= "-" then return desc end
    end
  end
  if type(GetItemLinkEnchantInfo) == "function" then
    local ok, a, b, c, d, e, f = pcall(GetItemLinkEnchantInfo, itemLink)
    if ok then
      local best = nil
      for _, v in ipairs({ a, b, c, d, e, f }) do
        if type(v) == "string" and v ~= "" then
          local s = stripColorLocal(v)
          if type(zo_strformat) == "function" then
            local okF, fmt = pcall(zo_strformat, "<<1>>", s)
            if okF and fmt then s = fmt end
          end
          if s ~= "" and s ~= "-" and ((not best) or #s > #best) then best = s end
        end
      end
      if best then return best end
    end
  end
  return "—"
end

local function extractTraitTextLocal(itemLink)
  if not itemLink or itemLink == "" then return "—" end
  if type(GetItemLinkTraitInfo) == "function" then
    local ok, a, b, c, d, e, f = pcall(GetItemLinkTraitInfo, itemLink)
    if ok then
      local best = nil
      for _, v in ipairs({ a, b, c, d, e, f }) do
        if type(v) == "string" and v ~= "" then
          local s = stripColorLocal(v)
          if type(zo_strformat) == "function" then
            local okF, fmt = pcall(zo_strformat, "<<1>>", s)
            if okF and fmt then s = fmt end
          end
          if s ~= "" and s ~= "-" and ((not best) or #s > #best) then best = s end
        end
      end
      if best then return best end
    end
  end
  if type(GetItemLinkTraitDescription) == "function" then
    local ok, desc = pcall(GetItemLinkTraitDescription, itemLink)
    if ok and desc and desc ~= "" then
      return stripColorLocal(desc)
    end
  end
  return "—"
end

-- Item quality → UI color + short label (what is / isn't golded at a glance)
local function itemQualityStyle(link)
  -- Returns r,g,b,a, label ("Gold"/"Purple"/"Blue"/…)
  local q = nil
  if type(link) == "string" and link ~= "" then
    if type(GetItemLinkDisplayQuality) == "function" then
      local ok, v = pcall(GetItemLinkDisplayQuality, link)
      if ok then q = tonumber(v) end
    end
    if not q and type(GetItemLinkQuality) == "function" then
      local ok, v = pcall(GetItemLinkQuality, link)
      if ok then q = tonumber(v) end
    end
  end
  local mythic = _G.ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE or _G.ITEM_QUALITY_MYTHIC or 6
  local legendary = _G.ITEM_DISPLAY_QUALITY_LEGENDARY or _G.ITEM_QUALITY_LEGENDARY or 5
  local epic = _G.ITEM_DISPLAY_QUALITY_EPIC or _G.ITEM_QUALITY_EPIC or 4
  local superior = _G.ITEM_DISPLAY_QUALITY_SUPERIOR or _G.ITEM_QUALITY_SUPERIOR or 3
  local fine = _G.ITEM_DISPLAY_QUALITY_FINE or _G.ITEM_QUALITY_FINE or 2
  local normal = _G.ITEM_DISPLAY_QUALITY_NORMAL or _G.ITEM_QUALITY_NORMAL or 1
  q = tonumber(q) or 0

  local function qualityLabelFor(qv)
    if mythic and qv == mythic then return "Mythic" end
    if qv >= 6 and not epic then return "Mythic" end -- some clients use 6 for mythic
    if legendary and qv == legendary then return "Gold" end
    if epic and qv == epic then return "Purple" end
    if superior and qv == superior then return "Blue" end
    if fine and qv == fine then return "Green" end
    if normal and qv == normal then return "White" end
    if qv == 5 then return "Gold" end
    if qv == 4 then return "Purple" end
    if qv == 3 then return "Blue" end
    if qv == 2 then return "Green" end
    if qv == 1 then return "White" end
    return "Q" .. tostring(qv)
  end

  local label = qualityLabelFor(q)
  -- Mythic: force darker orange (game API often returns purple-ish)
  if label == "Mythic" or (mythic and q == mythic) or q >= 6 then
    return 0.92, 0.48, 0.12, 1, "Mythic" -- dark orange
  end
  -- Prefer game color for non-mythic
  if q > 0 and type(GetItemQualityColor) == "function" then
    local ok, r, g, b = pcall(GetItemQualityColor, q)
    if ok and tonumber(r) then
      return tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, 1, label
    end
  end
  if label == "Gold" or q == legendary or q == 5 then return 0.93, 0.80, 0.30, 1, "Gold" end
  if label == "Purple" or q == epic or q == 4 then return 0.70, 0.40, 0.95, 1, "Purple" end
  if label == "Blue" or q == superior or q == 3 then return 0.35, 0.65, 0.95, 1, "Blue" end
  if label == "Green" or q == fine or q == 2 then return 0.35, 0.85, 0.40, 1, "Green" end
  if label == "White" or q == 1 then return 0.88, 0.88, 0.88, 1, "White" end
  return THEME.textR, THEME.textG, THEME.textB, 1, "—"
end

local function buildWornGearRows()
  local rows = {}
  if type(GetItemLink) ~= "function" or type(BAG_WORN) == "nil" then return rows end
  local slotDefs = {
    { "Head", "EQUIP_SLOT_HEAD" }, { "Shoulders", "EQUIP_SLOT_SHOULDERS" },
    { "Chest", "EQUIP_SLOT_CHEST" }, { "Hands", "EQUIP_SLOT_HAND" },
    { "Waist", "EQUIP_SLOT_WAIST" }, { "Legs", "EQUIP_SLOT_LEGS" },
    { "Feet", "EQUIP_SLOT_FEET" }, { "Neck", "EQUIP_SLOT_NECK" },
    { "Ring 1", "EQUIP_SLOT_RING1" }, { "Ring 2", "EQUIP_SLOT_RING2" },
    { "Front MH", "EQUIP_SLOT_MAIN_HAND" }, { "Front OH", "EQUIP_SLOT_OFF_HAND" },
    { "Back MH", "EQUIP_SLOT_BACKUP_MAIN" }, { "Back OH", "EQUIP_SLOT_BACKUP_OFF" },
  }
  local goldN, purpleN, blueN, mythicN, otherN = 0, 0, 0, 0, 0
  for _, def in ipairs(slotDefs) do
    local slotId = _G[def[2]]
    if type(slotId) == "number" then
      local ok, link = pcall(GetItemLink, BAG_WORN, slotId)
      local name, trait, enchant, itemIcon = "—", "—", "—", nil
      local qr, qg, qb, qa, qLabel = THEME.textR, THEME.textG, THEME.textB, 1, "—"
      if ok and link and link ~= "" then
        if type(GetItemLinkName) == "function" then
          local okName, n = pcall(GetItemLinkName, link)
          if okName and n and n ~= "" then
            name = (type(zo_strformat) == "function") and zo_strformat("<<1>>", n) or n
          end
        end
        if type(GetItemLinkIcon) == "function" then
          local okI, tex = pcall(GetItemLinkIcon, link)
          if okI and tex and not isBadIconTex(tex) then itemIcon = tex end
        end
        trait = extractTraitTextLocal(link)
        enchant = extractEnchantTextLocal(link)
        qr, qg, qb, qa, qLabel = itemQualityStyle(link)
        if qLabel == "Gold" then goldN = goldN + 1
        elseif qLabel == "Purple" then purpleN = purpleN + 1
        elseif qLabel == "Blue" then blueN = blueN + 1
        elseif qLabel == "Mythic" then mythicN = mythicN + 1
        elseif name ~= "—" then otherN = otherN + 1 end
      end
      rows[#rows + 1] = {
        slot = def[1],
        slotIcon = GEAR_SLOT_ICON[def[1]],
        itemIcon = itemIcon,
        item = name,
        trait = trait,
        enchant = enchant,
        qualityR = qr, qualityG = qg, qualityB = qb, qualityA = qa,
        qualityLabel = qLabel,
      }
    end
  end
  rows._qualitySummary = { gold = goldN, purple = purpleN, blue = blueN, mythic = mythicN, other = otherN }
  return rows
end

local function createGearUI(screen)
  if screen.gearUI and not screen.gearUI._v3151 then screen.gearUI = nil end
  if screen.gearUI then return screen.gearUI end
  ensureContentHost(screen)
  local panel = screen.contentPanels and screen.contentPanels.gear
  if not panel then return nil end
  local ui = {
    panel = panel,
    setLines = {},
    wornRows = {},
    barIcons = { front = {}, back = {} },
    _v3151 = true,
  }

  ui.root = WM:CreateControl("DM2StatsMenuGearRootV9", panel, CT_CONTROL)
  ui.root:SetAnchor(TOPLEFT, panel, TOPLEFT, 8, 4)
  stampForeground(ui.root, 55)

  ui.title = makeDashLabel(ui.root, "DM2StatsMenuGearTitleV9", 16, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.title:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, 0)
  ui.title:SetText("GEAR SUMMARY")

  ui.meta = makeDashLabel(ui.root, "DM2StatsMenuGearMetaV9", 13, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.meta:SetAnchor(TOPLEFT, ui.title, BOTTOMLEFT, 0, 2)
  ui.meta:SetText("Bars + sets from parse snapshot · worn slots are live (current character)")

  ui.barsPanel = WM:CreateControl("DM2StatsMenuGearBarsV9", ui.root, CT_CONTROL)
  local barsBg = makeSectionFrame(ui.barsPanel, "DM2StatsMenuGearBarsBGV9", true)
  barsBg:SetAnchorFill(ui.barsPanel)
  ui.barHead = makeDashLabel(ui.barsPanel, "DM2StatsMenuGearBarHeadV9", 14, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.barHead:SetAnchor(TOPLEFT, ui.barsPanel, TOPLEFT, 10, 6)
  ui.barHead:SetText("ACTION BARS (parse snapshot)")
  ui.frontTitle = makeDashLabel(ui.barsPanel, "DM2StatsMenuGearFrontV9", 13, THEME.frontR, THEME.frontG, THEME.frontB, 1)
  ui.frontTitle:SetText("Front")
  ui.backTitle = makeDashLabel(ui.barsPanel, "DM2StatsMenuGearBackV9", 13, THEME.backR, THEME.backG, THEME.backB, 1)
  ui.backTitle:SetText("Back")

  for _, barKey in ipairs({ "front", "back" }) do
    for i = 1, 6 do
      local slotBg = WM:CreateControl("DM2StatsMenuGearV9" .. barKey .. "Slot" .. i, ui.barsPanel, CT_BACKDROP)
      slotBg:SetDimensions(BAR_ICON_SIZE + 4, BAR_ICON_SIZE + 4)
      slotBg:SetCenterColor(0.14, 0.12, 0.09, 0.95)
      slotBg:SetEdgeColor(THEME.cardEdgeR, THEME.cardEdgeG, THEME.cardEdgeB, 0.75)
      stampBackground(slotBg, 4)
      local icon = WM:CreateControl("DM2StatsMenuGearV9" .. barKey .. "Icon" .. i, slotBg, CT_TEXTURE)
      icon:SetDimensions(BAR_ICON_SIZE, BAR_ICON_SIZE)
      icon:SetAnchor(CENTER, slotBg, CENTER, 0, 0)
      stampForeground(icon, 110)
      ui.barIcons[barKey][i] = { bg = slotBg, icon = icon }
    end
  end

  ui.listPanel = WM:CreateControl("DM2StatsMenuGearListV9", ui.root, CT_CONTROL)
  local listBg = makeSectionFrame(ui.listPanel, "DM2StatsMenuGearListBGV9", true)
  listBg:SetAnchorFill(ui.listPanel)
  ui.listTitle = makeDashLabel(ui.listPanel, "DM2StatsMenuGearListTitleV9", 14, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.listTitle:SetAnchor(TOPLEFT, ui.listPanel, TOPLEFT, 10, 6)
  ui.listTitle:SetText("SETS + WORN GEAR")

  ui.setsTitle = makeDashLabel(ui.listPanel, "DM2StatsMenuGearSetsTitleV9", 12, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.setsTitle:SetText("Sets on this parse")
  for i = 1, GEAR_SET_LINES do
    ui.setLines[i] = makeDashLabel(ui.listPanel, "DM2StatsMenuGearSetV9_" .. i, 13, THEME.textR, THEME.textG, THEME.textB, 1)
  end

  ui.wornTitle = makeDashLabel(ui.listPanel, "DM2StatsMenuGearWornTitleV9", 12, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.wornTitle:SetText("Live worn  ·  names colored by upgrade quality")
  ui.wornQuality = makeDashLabel(ui.listPanel, "DM2StatsMenuGearWornQV9", 11, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.wornQuality:SetText("|cEECC4CGold|r · |cB366F2Purple|r · |c59A6F2Blue|r · |cEB7A1FMythic|r · green/white = not golded")
  ui.hdrSlot = makeDashLabel(ui.listPanel, "DM2StatsMenuGearHdrSlotV9", 11, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.hdrSlot:SetText("Slot")
  ui.hdrItem = makeDashLabel(ui.listPanel, "DM2StatsMenuGearHdrItemV9", 11, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.hdrItem:SetText("Item (quality color)")
  ui.hdrTrait = makeDashLabel(ui.listPanel, "DM2StatsMenuGearHdrTraitV9", 11, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.hdrTrait:SetText("Trait")
  ui.hdrEnch = makeDashLabel(ui.listPanel, "DM2StatsMenuGearHdrEnchV9", 11, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.hdrEnch:SetText("Enchantment")

  for i = 1, GEAR_WORN_ROWS do
    local row = WM:CreateControl("DM2StatsMenuGearWornRowV90_" .. i, ui.listPanel, CT_CONTROL)
    local slotIcon = WM:CreateControl("DM2StatsMenuGearWornSlotIconV90_" .. i, row, CT_TEXTURE)
    slotIcon:SetDimensions(22, 22)
    stampForeground(slotIcon, 110)
    local slotName = makeDashLabel(row, "DM2StatsMenuGearWornSlotV90_" .. i, 13, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
    local itemIcon = WM:CreateControl("DM2StatsMenuGearWornItemIconV90_" .. i, row, CT_TEXTURE)
    itemIcon:SetDimensions(20, 20)
    stampForeground(itemIcon, 110)
    local item = makeDashLabel(row, "DM2StatsMenuGearWornItemV90_" .. i, 13, THEME.textR, THEME.textG, THEME.textB, 1)
    item:SetMaxLineCount(1)
    local trait = makeDashLabel(row, "DM2StatsMenuGearWornTraitV90_" .. i, 12, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
    trait:SetMaxLineCount(1)
    local ench = makeDashLabel(row, "DM2StatsMenuGearWornEnchV90_" .. i, 12, 0.78, 0.72, 0.52, 1)
    ench:SetMaxLineCount(1)
    ui.wornRows[i] = {
      row = row, slotIcon = slotIcon, slotName = slotName,
      itemIcon = itemIcon, item = item, trait = trait, ench = ench,
    }
  end

  ui.empty = makeDashLabel(ui.root, "DM2StatsMenuGearEmptyV9", 15, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.empty:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, 48)
  ui.empty:SetHidden(true)

  screen.gearUI = ui
  return ui
end

local function layoutGearUI(ui, hostW, hostH)
  if not ui or not ui.root then return end
  local W = math.max(480, (hostW or 900) - 8)
  local H = math.max(400, (hostH or 700) - 8)
  ui.root:ClearAnchors()
  ui.root:SetAnchor(TOPLEFT, ui.panel, TOPLEFT, 8, 4)
  ui.root:SetDimensions(W, H)
  ui.title:SetWidth(W)
  ui.meta:SetWidth(W)
  ui.empty:SetWidth(W)

  local barsH = 118
  ui.barsPanel:ClearAnchors()
  ui.barsPanel:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, 40)
  ui.barsPanel:SetDimensions(W, barsH)
  ui.barHead:SetWidth(W - 20)
  ui.frontTitle:ClearAnchors()
  ui.frontTitle:SetAnchor(TOPLEFT, ui.barsPanel, TOPLEFT, 10, 28)
  ui.backTitle:ClearAnchors()
  ui.backTitle:SetAnchor(TOPLEFT, ui.barsPanel, TOPLEFT, 10, 72)
  local slotGap = 8
  local slotStep = BAR_ICON_SIZE + 4 + slotGap
  for _, barKey in ipairs({ "front", "back" }) do
    local y = (barKey == "front") and 26 or 70
    for i = 1, 6 do
      local slot = ui.barIcons[barKey][i]
      if slot and slot.bg then
        slot.bg:ClearAnchors()
        slot.bg:SetAnchor(TOPLEFT, ui.barsPanel, TOPLEFT, 70 + (i - 1) * slotStep, y)
      end
    end
  end

  local listY = 40 + barsH + 6
  local listH = H - listY - 4
  ui.listPanel:ClearAnchors()
  ui.listPanel:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, listY)
  ui.listPanel:SetDimensions(W, listH)
  ui.listTitle:SetWidth(W - 20)

  -- Sets strip (compact)
  local y = 26
  ui.setsTitle:ClearAnchors()
  ui.setsTitle:SetAnchor(TOPLEFT, ui.listPanel, TOPLEFT, 12, y)
  ui.setsTitle:SetWidth(W - 24)
  y = y + 16
  for i = 1, GEAR_SET_LINES do
    local line = ui.setLines[i]
    if line then
      line:ClearAnchors()
      line:SetAnchor(TOPLEFT, ui.listPanel, TOPLEFT, 14, y)
      line:SetWidth(W - 28)
      line:SetMaxLineCount(1)
    end
    y = y + 16
  end

  y = y + 6
  ui.wornTitle:ClearAnchors()
  ui.wornTitle:SetAnchor(TOPLEFT, ui.listPanel, TOPLEFT, 12, y)
  ui.wornTitle:SetWidth(W - 24)
  y = y + 16
  if ui.wornQuality then
    ui.wornQuality:ClearAnchors()
    ui.wornQuality:SetAnchor(TOPLEFT, ui.listPanel, TOPLEFT, 12, y)
    ui.wornQuality:SetWidth(W - 24)
  end
  y = y + 16

  -- Slot | Item | Trait (long) | Enchantment (long, starts further right)
  -- Fixed columns so long trait text does not shove enchant out of alignment.
  local iconCol = 10
  local slotCol = 34
  local slotW = 52
  local itemIconCol = slotCol + slotW + 2
  local itemCol = itemIconCol + 22
  local itemW = math.min(170, math.max(120, math.floor((W - 40) * 0.15)))
  local traitCol = itemCol + itemW + 8
  local traitW = math.min(520, math.max(340, math.floor((W - 40) * 0.38)))
  local enchCol = traitCol + traitW + 12
  local enchW = math.max(260, W - enchCol - 12)
  -- Slightly more chars (~5.8px/char) so descriptions use available width
  ui._gearItemChars = math.max(20, math.floor(itemW / 6.2))
  ui._gearTraitChars = math.max(56, math.floor(traitW / 5.8))
  ui._gearEnchChars = math.max(48, math.floor(enchW / 5.8))

  ui.hdrSlot:ClearAnchors()
  ui.hdrSlot:SetAnchor(TOPLEFT, ui.listPanel, TOPLEFT, slotCol, y)
  ui.hdrSlot:SetWidth(slotW)
  ui.hdrItem:ClearAnchors()
  ui.hdrItem:SetAnchor(TOPLEFT, ui.listPanel, TOPLEFT, itemCol, y)
  ui.hdrItem:SetWidth(itemW)
  if ui.hdrTrait then
    ui.hdrTrait:ClearAnchors()
    ui.hdrTrait:SetAnchor(TOPLEFT, ui.listPanel, TOPLEFT, traitCol, y)
    ui.hdrTrait:SetWidth(traitW)
  end
  ui.hdrEnch:ClearAnchors()
  ui.hdrEnch:SetAnchor(TOPLEFT, ui.listPanel, TOPLEFT, enchCol, y)
  ui.hdrEnch:SetWidth(enchW)
  y = y + 16

  local rowH = math.floor((listH - y - 4) / GEAR_WORN_ROWS)
  if rowH < 22 then rowH = 22 end
  if rowH > 28 then rowH = 28 end
  for i = 1, GEAR_WORN_ROWS do
    local r = ui.wornRows[i]
    if r then
      r.row:ClearAnchors()
      r.row:SetAnchor(TOPLEFT, ui.listPanel, TOPLEFT, 8, y + (i - 1) * rowH)
      r.row:SetDimensions(W - 16, rowH - 1)
      r.slotIcon:ClearAnchors()
      r.slotIcon:SetAnchor(LEFT, r.row, LEFT, iconCol - 8, 0)
      r.slotName:ClearAnchors()
      r.slotName:SetAnchor(LEFT, r.row, LEFT, slotCol - 8, 0)
      r.slotName:SetWidth(slotW)
      r.itemIcon:ClearAnchors()
      r.itemIcon:SetAnchor(LEFT, r.row, LEFT, itemIconCol - 8, 0)
      r.item:ClearAnchors()
      r.item:SetAnchor(LEFT, r.row, LEFT, itemCol - 8, 0)
      r.item:SetWidth(itemW)
      if r.trait then
        r.trait:ClearAnchors()
        r.trait:SetAnchor(TOPLEFT, r.row, TOPLEFT, traitCol - 8, 2)
        r.trait:SetWidth(traitW)
        if r.trait.SetMaxLineCount then r.trait:SetMaxLineCount(1) end
      end
      r.ench:ClearAnchors()
      r.ench:SetAnchor(TOPLEFT, r.row, TOPLEFT, enchCol - 8, 2)
      r.ench:SetWidth(enchW)
      if r.ench.SetMaxLineCount then r.ench:SetMaxLineCount(1) end
    end
  end
end

local function refreshGearUI(screen, session)
  local ui = createGearUI(screen)
  if not ui then return end
  local hostW, hostH = layoutContentHost(screen)
  layoutGearUI(ui, hostW, hostH)

  if not session then
    ui.empty:SetText("History is empty.")
    ui.empty:SetHidden(false)
    ui.barsPanel:SetHidden(true)
    ui.listPanel:SetHidden(true)
    refreshBarIcons(ui.barIcons.front, {})
    refreshBarIcons(ui.barIcons.back, {})
    return
  end
  ui.empty:SetHidden(true)
  ui.barsPanel:SetHidden(false)
  ui.listPanel:SetHidden(false)
  refreshBarIcons(ui.barIcons.front, collectBarSlots(session, "Front"))
  refreshBarIcons(ui.barIcons.back, collectBarSlots(session, "Back"))

  -- Sets
  local sets = {}
  if type(session.equippedSets) == "table" then
    for i, name in ipairs(session.equippedSets) do sets[i] = name end
  end
  for i = 1, GEAR_SET_LINES do
    local line = ui.setLines[i]
    if line then
      if sets[i] then
        line:SetHidden(false)
        line:SetText(string.format("|c88DDAA%d.|r  %s", i, tostring(sets[i])))
      elseif i == 1 then
        line:SetHidden(false)
        line:SetText("|cAAAAAANo set names on this parse snapshot.|r")
      else
        line:SetHidden(true)
      end
    end
  end

  -- Worn table
  local worn = buildWornGearRows()
  for i = 1, GEAR_WORN_ROWS do
    local r = ui.wornRows[i]
    local d = worn[i]
    if r then
      if d then
        r.row:SetHidden(false)
        if d.slotIcon then
          r.slotIcon:SetTexture(d.slotIcon)
          r.slotIcon:SetHidden(false)
          r.slotIcon:SetColor(0.85, 0.78, 0.55, 1)
        else
          r.slotIcon:SetHidden(true)
        end
        r.slotName:SetText(d.slot or "")
        if d.itemIcon then
          r.itemIcon:SetTexture(d.itemIcon)
          r.itemIcon:SetHidden(false)
          r.itemIcon:SetColor(1, 1, 1, 1)
        else
          r.itemIcon:SetHidden(true)
        end
        -- Name in upgrade quality color (gold / purple / blue / dark-orange mythic)
        local itemChars = ui._gearItemChars or 32
        local traitChars = ui._gearTraitChars or 64
        local enchChars = ui._gearEnchChars or 80
        r.item:SetText(truncateText(d.item or "—", itemChars))
        r.item:SetColor(
          tonumber(d.qualityR) or THEME.textR,
          tonumber(d.qualityG) or THEME.textG,
          tonumber(d.qualityB) or THEME.textB,
          tonumber(d.qualityA) or 1
        )
        if r.trait then r.trait:SetText(truncateText(d.trait or "—", traitChars)) end
        r.ench:SetText(truncateText(d.enchant or "—", enchChars))
      else
        r.row:SetHidden(true)
      end
    end
  end
  if ui.wornQuality then
    local s = worn._qualitySummary
    if s then
      ui.wornQuality:SetText(string.format(
        "|cEECC4CGold %d|r  ·  |cB366F2Purple %d|r  ·  |c59A6F2Blue %d|r  ·  |cEB7A1FMythic %d|r  ·  other %d  ·  live loadout",
        s.gold or 0, s.purple or 0, s.blue or 0, s.mythic or 0, s.other or 0
      ))
    end
  end
end

---------------------------------------------------------------------
-- Rotation: summary + fine pulse + skill icons + pattern tips
---------------------------------------------------------------------
local function createRotationUI(screen)
  if screen.rotationUI and not screen.rotationUI._v31805 then
    if screen.rotationUI.root and type(screen.rotationUI.root.SetHidden) == "function" then
      screen.rotationUI.root:SetHidden(true)
    end
    screen.rotationUI = nil
  end
  if screen.rotationUI then return screen.rotationUI end
  ensureContentHost(screen)
  local panel = screen.contentPanels and screen.contentPanels.rotation
  if not panel then return nil end
  local ui = { panel = panel, pulse = {}, icons = {}, patterns = {}, _v31805 = true }

  ui.root = WM:CreateControl("DM2StatsMenuRotRootV8", panel, CT_CONTROL)
  ui.root:SetAnchor(TOPLEFT, panel, TOPLEFT, 4, 2)
  stampForeground(ui.root, 55)
  ui.title = makeDashLabel(ui.root, "DM2StatsMenuRotTitleV8", 16, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.title:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, 0)
  ui.title:SetText("ROTATION DIAGNOSTICS")
  ui.meta = makeDashLabel(ui.root, "DM2StatsMenuRotMetaV8", 12, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.meta:SetAnchor(TOPLEFT, ui.title, BOTTOMLEFT, 0, 2)
  ui.meta:SetText("|c66FF66border = good|r  |cFFCC66late|r  |cFF6666missed|r  |c66AAFFtoo fast|r  ·  top bar = cast pace  ·  |c88DDAAS|r swap / |cFFAA66U|r ult under icons")

  ui.sumPanel = WM:CreateControl("DM2StatsMenuRotSumV8", ui.root, CT_CONTROL)
  local sbg = makeSectionFrame(ui.sumPanel, "DM2StatsMenuRotSumBGV8", true)
  sbg:SetAnchorFill(ui.sumPanel)
  ui.sumLine1 = makeDashLabel(ui.sumPanel, "DM2StatsMenuRotSum1V8", 17, THEME.textR, THEME.textG, THEME.textB, 1)
  ui.sumLine1:SetAnchor(TOPLEFT, ui.sumPanel, TOPLEFT, 12, 8)
  ui.sumLine2 = makeDashLabel(ui.sumPanel, "DM2StatsMenuRotSum2V8", 14, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.sumLine2:SetAnchor(TOPLEFT, ui.sumPanel, TOPLEFT, 12, 30)
  -- Exec detail only in header (S/U sit under each skill icon)
  ui.execLine = makeDashLabel(ui.sumPanel, "DM2StatsMenuRotExecV8", 12, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.execLine:SetAnchor(TOPLEFT, ui.sumPanel, TOPLEFT, 12, 50)
  ui.execLine:SetMaxLineCount(2)

  ui.pulsePanel = WM:CreateControl("DM2StatsMenuRotPulsePanelV8", ui.root, CT_CONTROL)
  local pbg = makeSectionFrame(ui.pulsePanel, "DM2StatsMenuRotPulseBGV8", true)
  pbg:SetAnchorFill(ui.pulsePanel)
  ui.pulseTitle = makeDashLabel(ui.pulsePanel, "DM2StatsMenuRotPulseTitleV8", 13, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.pulseTitle:SetAnchor(TOPLEFT, ui.pulsePanel, TOPLEFT, 10, 4)
  ui.pulseTitle:SetText("WEAVE PULSE  (fine grain — each block ≈ a few presses)")
  ui.pulseWrap = WM:CreateControl("DM2StatsMenuRotPulseWrapV8", ui.pulsePanel, CT_CONTROL)
  for i = 1, PULSE_BLOCKS do
    local block = WM:CreateControl("DM2StatsMenuRotPulseV8_" .. i, ui.pulseWrap, CT_BACKDROP)
    block:SetEdgeColor(0, 0, 0, 0)
    block:SetHidden(true)
    stampForeground(block, 100)
    ui.pulse[i] = block
  end

  ui.iconPanel = WM:CreateControl("DM2StatsMenuRotIconPanelV8", ui.root, CT_CONTROL)
  local ibg = makeSectionFrame(ui.iconPanel, "DM2StatsMenuRotIconBGV8", true)
  ibg:SetAnchorFill(ui.iconPanel)
  ui.iconTitle = makeDashLabel(ui.iconPanel, "DM2StatsMenuRotIconTitleV8", 13, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.iconTitle:SetAnchor(TOPLEFT, ui.iconPanel, TOPLEFT, 10, 4)
  ui.iconTitle:SetText("SKILL TIMELINE  ·  |c88DDAAS|r bar swap · |cFFAA66U|r ult under icon = when it happened")
  ui.iconWrap = WM:CreateControl("DM2StatsMenuRotIconWrapV8", ui.iconPanel, CT_CONTROL)
  -- Legend line only (per-icon S/U tags are under each halo)
  ui.iconMarkerLine = makeDashLabel(ui.iconPanel, "DM2StatsMenuRotIconMarkV8", 11, 0.55, 0.75, 0.70, 1)
  ui.iconMarkerLine:SetMaxLineCount(1)
  -- Pace key sits one line above the visible-icons footer.
  ui.iconPaceLine = makeDashLabel(ui.iconPanel, "DM2StatsMenuRotIconPaceV11", 11, 0.72, 0.90, 0.78, 1)
  ui.iconPaceLine:SetMaxLineCount(1)
  -- Nested: avoid extra main-chunk locals (ESO 200-local cap).
  ui.ensurePool = function(needed)
    local wrap = ui.iconWrap
    if not wrap then return 0 end
    ui.icons = ui.icons or {}
    needed = tonumber(needed) or 96
    if needed < 1 then needed = 1 end
    if needed > ROT_TIMELINE_ICONS then needed = ROT_TIMELINE_ICONS end
    for i = #ui.icons + 1, needed do
      local halo = WM:CreateControl("DM2StatsMenuRotIconHaloV10_" .. i, wrap, CT_BACKDROP)
      halo:SetDimensions(36, 36)
      halo:SetCenterColor(0.35, 0.92, 0.45, 0.95)
      halo:SetEdgeColor(0, 0, 0, 0)
      halo:SetHidden(true)
      stampBackground(halo, 3)
      local slot = WM:CreateControl("DM2StatsMenuRotIconSlotV10_" .. i, halo, CT_BACKDROP)
      slot:SetDimensions(28, 28)
      slot:SetCenterColor(0.06, 0.06, 0.07, 1)
      slot:SetEdgeColor(0.15, 0.15, 0.16, 0.9)
      slot:SetAnchor(CENTER, halo, CENTER, 0, 0)
      stampBackground(slot, 4)
      local tex = WM:CreateControl("DM2StatsMenuRotIconTexV10_" .. i, slot, CT_TEXTURE)
      tex:SetDimensions(24, 24)
      tex:SetAnchor(CENTER, slot, CENTER, 0, 0)
      stampForeground(tex, 110)
      local fall = makeDashLabel(slot, "DM2StatsMenuRotIconFallV10_" .. i, 12, THEME.textR, THEME.textG, THEME.textB, 1)
      fall:SetAnchor(CENTER, slot, CENTER, 0, 0)
      fall:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
      fall:SetHidden(true)
      local cap = WM:CreateControl("DM2StatsMenuRotIconCapV11_" .. i, halo, CT_BACKDROP)
      cap:SetDimensions(36, 3)
      cap:SetAnchor(TOPLEFT, halo, TOPLEFT, 0, 0)
      cap:SetCenterColor(0.35, 0.92, 0.45, 1)
      cap:SetEdgeColor(0, 0, 0, 0)
      cap:SetHidden(true)
      stampForeground(cap, 80)
      local tick = WM:CreateControl("DM2StatsMenuRotIconTickV11_" .. i, cap, CT_BACKDROP)
      tick:SetDimensions(2, 3)
      tick:SetAnchor(TOPLEFT, cap, TOPLEFT, 0, 0)
      tick:SetCenterColor(0.05, 0.05, 0.06, 1)
      tick:SetEdgeColor(0, 0, 0, 0)
      tick:SetHidden(true)
      stampForeground(tick, 90)
      local barTag = makeDashLabel(halo, "DM2StatsMenuRotIconBarV10_" .. i, 10, 1, 1, 1, 1)
      barTag:SetAnchor(TOPLEFT, halo, TOPLEFT, 1, -1)
      barTag:SetHidden(true)
      local markTag = makeDashLabel(wrap, "DM2StatsMenuRotIconMkV10_" .. i, 11, 0.55, 0.92, 0.75, 1)
      markTag:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
      markTag:SetHidden(true)
      ui.icons[i] = { halo = halo, slot = slot, tex = tex, fall = fall, cap = cap, tick = tick, barTag = barTag, markTag = markTag }
    end
    return #ui.icons
  end
  ui.ensurePool(96)

  ui.patPanel = WM:CreateControl("DM2StatsMenuRotPatPanelV8", ui.root, CT_CONTROL)
  local patBg = makeSectionFrame(ui.patPanel, "DM2StatsMenuRotPatBGV8", true)
  patBg:SetAnchorFill(ui.patPanel)
  ui.patTitle = makeDashLabel(ui.patPanel, "DM2StatsMenuRotPatTitleV8", 13, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.patTitle:SetAnchor(TOPLEFT, ui.patPanel, TOPLEFT, 10, 4)
  ui.patTitle:SetText("PATTERNS  (this fight)")
  for i = 1, 4 do
    ui.patterns[i] = makeDashLabel(ui.patPanel, "DM2StatsMenuRotPatV8_" .. i, 13, THEME.textR, THEME.textG, THEME.textB, 1)
  end

  screen.rotationUI = ui
  return ui
end

local function layoutRotationUI(ui, hostW, hostH)
  if not ui or not ui.root then return end
  local W = math.max(440, (hostW or 900) - 4)
  local H = math.max(400, (hostH or 700) - 4)
  ui.root:ClearAnchors()
  ui.root:SetAnchor(TOPLEFT, ui.panel, TOPLEFT, 2, 0)
  ui.root:SetDimensions(W, H)
  ui.title:SetWidth(W)
  ui.meta:SetWidth(W)

  local sumH, pulseH = 78, 44
  ui.sumPanel:ClearAnchors()
  ui.sumPanel:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, 40)
  ui.sumPanel:SetDimensions(W, sumH)
  ui.sumLine1:SetWidth(W - 24)
  ui.sumLine2:SetWidth(W - 24)
  if ui.markerLine then
    ui.markerLine:SetHidden(true)
    ui.markerLine:SetText("")
  end
  if ui.execLine then ui.execLine:SetWidth(W - 24) end

  local pulseY = 40 + sumH + 4
  ui.pulsePanel:ClearAnchors()
  ui.pulsePanel:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, pulseY)
  ui.pulsePanel:SetDimensions(W, pulseH)
  ui.pulseTitle:SetWidth(W - 16)
  ui.pulseWrap:ClearAnchors()
  ui.pulseWrap:SetAnchor(TOPLEFT, ui.pulsePanel, TOPLEFT, 8, 22)
  ui.pulseWrap:SetDimensions(W - 16, 16)

  -- Keep patterns fully above the gamepad keybind bar (footer inset).
  -- Patterns fixed height (~3–4 lines); timeline takes remaining (grows with plate).
  local patH = 102
  local iconY = pulseY + pulseH + 4
  local iconH = H - iconY - patH - 6
  if iconH < 90 then iconH = 90 end
  ui.iconPanel:ClearAnchors()
  ui.iconPanel:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, iconY)
  ui.iconPanel:SetDimensions(W, iconH)
  ui.iconTitle:SetWidth(W - 16)
  ui.iconWrap:ClearAnchors()
  ui.iconWrap:SetAnchor(TOPLEFT, ui.iconPanel, TOPLEFT, 8, 22)
  -- Room for S/U tags, then the pace key, then the visible-icons line.
  ui.iconWrap:SetDimensions(W - 16, math.max(40, iconH - 58))
  if ui.iconPaceLine then
    ui.iconPaceLine:ClearAnchors()
    ui.iconPaceLine:SetAnchor(BOTTOMLEFT, ui.iconPanel, BOTTOMLEFT, 12, -20)
    ui.iconPaceLine:SetWidth(W - 24)
  end
  if ui.iconMarkerLine then
    ui.iconMarkerLine:ClearAnchors()
    ui.iconMarkerLine:SetAnchor(BOTTOMLEFT, ui.iconPanel, BOTTOMLEFT, 12, -4)
    ui.iconMarkerLine:SetWidth(W - 24)
  end

  ui.patPanel:ClearAnchors()
  ui.patPanel:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, iconY + iconH + 4)
  ui.patPanel:SetDimensions(W, patH)
  ui.patTitle:SetWidth(W - 16)
  for i = 1, 4 do
    local line = ui.patterns[i]
    if line then
      line:ClearAnchors()
      line:SetAnchor(TOPLEFT, ui.patPanel, TOPLEFT, 12, 22 + (i - 1) * 18)
      line:SetWidth(W - 24)
      line:SetMaxLineCount(1)
    end
  end
end

local function refreshRotationUI(screen, session)
  local ui = createRotationUI(screen)
  if not ui then return end
  local hostW, hostH = layoutContentHost(screen)
  layoutRotationUI(ui, hostW, hostH)
  local textW = math.max(400, hostW - 8)

  if not session then
    ui.sumLine1:SetText("No fight selected")
    ui.sumLine2:SetText("")
    if ui.markerLine then ui.markerLine:SetText(""); ui.markerLine:SetHidden(true) end
    if ui.iconMarkerLine then ui.iconMarkerLine:SetText(""); ui.iconMarkerLine:SetHidden(true) end
    if ui.iconPaceLine then ui.iconPaceLine:SetText(""); ui.iconPaceLine:SetHidden(true) end
    if ui.execLine then ui.execLine:SetText("") end
    for _, b in ipairs(ui.pulse) do b:SetHidden(true) end
    for _, ic in ipairs(ui.icons) do
      if ic.halo then ic.halo:SetHidden(true)
      elseif ic.slot then ic.slot:SetHidden(true) end
      if ic.markTag then ic.markTag:SetHidden(true) end
      if ic.barTag then ic.barTag:SetHidden(true) end
      if ic.cap then ic.cap:SetHidden(true) end
      if ic.tick then ic.tick:SetHidden(true) end
    end
    for i, line in ipairs(ui.patterns) do line:SetText(i == 1 and "Parse a fight to unlock patterns." or "") end
    return
  end

  local w = type(session.weave) == "table" and session.weave or {}
  ensurePhase3Summary(session)
  ui.meta:SetText(string.format(
    "%s  ·  %s  ·  |c66FF66good|r  |cFFCC66late|r  |cFF6666miss|r  |c66AAFFfast|r · border = weave · bar = pace",
    truncateText(session.lastTargetName or "fight", 28), fmtDur(session.durationMs)
  ))
  ui.sumLine1:SetText(string.format(
    "Weave |c66FF66%s|r    Good |c66FF66%d|r    Late |cFFCC66%d|r    Missed |cFF6666%d|r    Fast |c66AAFF%d|r",
    fmtPct(getWeaveSuccessRatio(session)),
    tonumber(w.onTimeCount) or 0, tonumber(w.lateCount) or 0,
    tonumber(w.missedCount) or 0, tonumber(w.tooFastCount) or 0
  ))
  local pace = M.SkillCastPace(session)
  local paceTxt = ""
  if pace.samples >= 8 then
    paceTxt = string.format("    Lost %0.3f s/cast", pace.medianLostMs / 1000)
  elseif pace.early >= 8 then
    paceTxt = "    Presses early"
  end
  ui.sumLine2:SetText(string.format(
    "LA hits %s    Skill presses %s    Bar swaps %s%s",
    tostring(sessionLaHits(session)),
    tostring(tonumber(w.inputSkillPresses) or tonumber(w.skillEventCount) or 0),
    tostring(tonumber(w.barSwapCount) or 0),
    paceTxt
  ))
  if ui.markerLine then
    ui.markerLine:SetText("")
    ui.markerLine:SetHidden(true)
  end
  if ui.execLine then
    local bs = session.barStats or {}
    local ue = session.ultEconomy or {}
    local best = session.windowStats and session.windowStats.bestActive20
    local worst = session.windowStats and session.windowStats.worstActive20
    ui.execLine:SetText(string.format(
      "Bars F %0.0f%%/B %0.0f%% · delay med %0.0fms p90 %0.0f · ult %d · best/worst active %s / %s",
      (tonumber(bs.frontDwell) or 0) * 100,
      (tonumber(bs.backDwell) or 0) * 100,
      tonumber(bs.delayMedian) or 0,
      tonumber(bs.delayP90) or 0,
      tonumber(ue.casts) or 0,
      best and fmtDps(best.dps) or "—",
      worst and fmtDps(worst.dps) or "—"
    ))
  end

  -- Fine pulse: more smaller blocks
  local ratios = buildPulseRatios(session, PULSE_BLOCKS)
  local wrapW = ui.pulseWrap:GetWidth() or textW
  if wrapW < 50 then wrapW = textW end
  local gap = 1
  local blockW = math.max(3, math.floor((wrapW - 2) / math.max(#ui.pulse, 1)) - gap)
  for i, block in ipairs(ui.pulse) do
    local ratio = ratios[i]
    if ratio then
      block:ClearAnchors()
      block:SetDimensions(blockW, 12)
      block:SetAnchor(TOPLEFT, ui.pulseWrap, TOPLEFT, (i - 1) * (blockW + gap), 2)
      local r, g, b, a = sparkColorForRatio(ratio)
      block:SetCenterColor(r, g, b, a)
      block:SetHidden(false)
    else
      block:SetHidden(true)
    end
  end

  -- Icon timeline — paint the whole dummy on one screen when the panel can hold it.
  -- Chips are GUI objects (halo+slot+tex+labels). We grow a pool up to the cap, then page.
  local wrapWW = ui.iconWrap:GetWidth() or textW
  local wrapHH = ui.iconWrap:GetHeight() or 120
  if wrapWW < 50 then wrapWW = textW end
  if wrapHH < 40 then wrapHH = 120 end
  local function gridMetrics(cellSize, iconGap, markH)
    local perRow = math.max(1, math.floor((wrapWW + iconGap) / (cellSize + iconGap)))
    local rowStride = cellSize + iconGap + markH
    local maxRows = math.max(1, math.floor((wrapHH + iconGap) / rowStride))
    return perRow, maxRows, perRow * maxRows, rowStride
  end
  local function pickCell(count)
    local tries = { {32,4,10}, {28,3,9}, {24,3,8}, {22,2,8} }
    local best = { cellSize=32, iconGap=4, markH=10, perRow=1, maxRows=1, maxFit=1, rowStride=46 }
    count = tonumber(count) or 0
    for _, t in ipairs(tries) do
      local perRow, maxRows, maxFit, stride = gridMetrics(t[1], t[2], t[3])
      best = { cellSize=t[1], iconGap=t[2], markH=t[3], perRow=perRow, maxRows=maxRows, maxFit=maxFit, rowStride=stride }
      if count > 0 and count <= maxFit then return best end
    end
    return best
  end
  local allEvents = collectSkillTimelineEvents(session)
  for i = 1, #allEvents do
    local ev = allEvents[i]
    local nxt = allEvents[i + 1]
    ev.toNextMs = nil
    ev.paceBand = nil
    if ev.result == "channel" then
      ev.paceBand = "channel"
    elseif nxt and ev.tMs and nxt.tMs then
      local span = nxt.tMs - ev.tMs
      if span > 0 then
        ev.toNextMs = span
        ev.paceBand = M.CastPaceBand(span)
      end
    end
  end
  local totalSkills = #allEvents
  local gridAll = pickCell(math.min(totalSkills, ROT_TIMELINE_ICONS))
  local pageCap = math.min(gridAll.maxFit, ROT_TIMELINE_ICONS)
  if pageCap < 1 then pageCap = 1 end
  if type(ui.ensurePool) == "function" then
    ui.ensurePool(math.min(math.max(totalSkills, 1), pageCap))
  end
  local pages = 1
  if totalSkills > pageCap then pages = math.ceil(totalSkills / pageCap) end
  M._rotTimelinePage = math.max(1, tonumber(M._rotTimelinePage) or 1)
  if M._rotTimelinePage > pages then M._rotTimelinePage = pages end
  local pageIndex = M._rotTimelinePage
  M._rotTimelinePages = pages
  M._rotTimelineTotal = totalSkills
  local startIdx = (pageIndex - 1) * pageCap + 1
  local events = {}
  for i = startIdx, math.min(totalSkills, startIdx + pageCap - 1) do
    events[#events + 1] = allEvents[i]
  end
  local endIdx = startIdx + #events - 1
  -- Size cells for this page (last page of 20 icons stays readable, not tiny)
  local grid = pickCell(#events)
  local cellSize, iconGap, markH = grid.cellSize, grid.iconGap, grid.markH
  local perRow, maxRowsFit, maxFit, rowStride = grid.perRow, grid.maxRows, grid.maxFit, grid.rowStride
  local pressCount = tonumber(w.inputSkillPresses) or tonumber(w.skillEventCount) or totalSkills
  local markTags, swapPlaced, ultPlaced = buildIconMarkerTags(session, events)
  local totalSwaps = (session.weave and tonumber(session.weave.barSwapCount))
    or (session.barStats and tonumber(session.barStats.swapCount)) or 0
  local markCount = 0
  local clipped = (#events > maxFit)
  if ui.iconTitle then
    if pages > 1 then
      ui.iconTitle:SetText(string.format(
        "SKILL TIMELINE  ·  icons %d–%d of %d  ·  presses %d  ·  page %d/%d  ·  footer Next page",
        startIdx, endIdx, totalSkills, pressCount, pageIndex, pages
      ))
    else
      ui.iconTitle:SetText(string.format(
        "SKILL TIMELINE  ·  %d skills this parse  ·  %d presses  ·  |c88DDAAS|r swap · |cFFAA66U|r ult",
        totalSkills, pressCount
      ))
    end
  end
  for i, ic in ipairs(ui.icons) do
    local ev = events[i]
    local host = ic.halo or ic.slot
    local row = math.floor((i - 1) / perRow)
    local fits = (row < maxRowsFit)
    if ev and host and fits then
      local col = (i - 1) % perRow
      local x = col * (cellSize + iconGap)
      local y = row * rowStride
      host:ClearAnchors()
      host:SetDimensions(cellSize, cellSize)
      host:SetAnchor(TOPLEFT, ui.iconWrap, TOPLEFT, x, y)
      local er, eg, eb = ev.edgeR or 0.5, ev.edgeG or 0.5, ev.edgeB or 0.5
      if ic.halo then
        ic.halo:SetCenterColor(er, eg, eb, 1)
        ic.halo:SetHidden(false)
      end
      if ic.slot then
        ic.slot:SetDimensions(cellSize - 8, cellSize - 8)
        ic.slot:ClearAnchors()
        ic.slot:SetAnchor(CENTER, host, CENTER, 0, 0)
        ic.slot:SetCenterColor(0.05, 0.05, 0.06, 1)
        ic.slot:SetEdgeColor(er * 0.55, eg * 0.55, eb * 0.55, 1)
        ic.slot:SetHidden(false)
      end
      if ev.icon then
        ic.tex:SetTexture(ev.icon)
        ic.tex:SetHidden(false)
        ic.tex:SetColor(1, 1, 1, 1)
        ic.tex:SetDimensions(cellSize - 12, cellSize - 12)
        if ic.fall then ic.fall:SetHidden(true) end
      else
        ic.tex:SetHidden(true)
        if ic.fall then
          local initials = ev.initials or shortSkillInitials(ev.name)
          ic.fall:SetText(initials)
          ic.fall:SetHidden(false)
        end
      end
      if ic.barTag then
        local tag = ""
        local tr, tg, tb = 0.05, 0.05, 0.06
        if ev.isUltimate then
          tag = "U"
        elseif ev.bar == "Front" or ev.bar == "front" or ev.bar == 1 then
          tag = "F"
        elseif ev.bar == "Back" or ev.bar == "back" or ev.bar == 2 then
          tag = "B"
        end
        if tag ~= "" then
          ic.barTag:SetText(tag)
          ic.barTag:SetColor(tr, tg, tb, 1)
          ic.barTag:SetHidden(false)
        else
          ic.barTag:SetHidden(true)
        end
      end
      if ic.cap then
        local band, pr, pg, pb = nil, nil, nil, nil
        if ev.paceBand and ev.paceBand ~= "channel" then
          band, pr, pg, pb = M.CastPaceBand(ev.toNextMs)
        end
        if band and pr then
          ic.cap:ClearAnchors()
          ic.cap:SetAnchor(TOPLEFT, host, TOPLEFT, 0, 0)
          ic.cap:SetDimensions(cellSize, 3)
          ic.cap:SetCenterColor(pr, pg, pb, 1)
          ic.cap:SetEdgeColor(0, 0, 0, 0)
          ic.cap:SetHidden(false)
          local laGap = tonumber(ev.gapMs) or 0
          local span = tonumber(ev.toNextMs) or 0
          if ic.tick and laGap > 0 and span > 0 and band ~= "stall" then
            local u = laGap / span
            if u < 0 then u = 0 end
            if u > 1 then u = 1 end
            ic.tick:ClearAnchors()
            ic.tick:SetAnchor(TOPLEFT, ic.cap, TOPLEFT, math.floor((cellSize - 2) * u), 0)
            ic.tick:SetDimensions(2, 3)
            ic.tick:SetCenterColor(0.05, 0.05, 0.06, 1)
            ic.tick:SetHidden(false)
          elseif ic.tick then
            ic.tick:SetHidden(true)
          end
        else
          ic.cap:SetHidden(true)
          if ic.tick then ic.tick:SetHidden(true) end
        end
      end
      -- Per-icon S/U under the box (when swap/ult happened near this skill)
      if ic.markTag then
        local mk = markTags[i]
        if mk and mk ~= "" then
          -- Support S, S3, SU, S2U1 etc.
          local colored = mk
            :gsub("S(%d*)", function(n)
              if n == "" then return "|c88DDAAS|r" end
              return "|c88DDAAS" .. n .. "|r"
            end)
            :gsub("U(%d*)", function(n)
              if n == "" then return "|cFFAA66U|r" end
              return "|cFFAA66U" .. n .. "|r"
            end)
          ic.markTag:ClearAnchors()
          ic.markTag:SetAnchor(TOP, host, BOTTOM, 0, 0)
          ic.markTag:SetWidth(cellSize + 8)
          ic.markTag:SetText(colored)
          ic.markTag:SetHidden(false)
          markCount = markCount + 1
        else
          ic.markTag:SetText("")
          ic.markTag:SetHidden(true)
        end
      end
    elseif host then
      -- No event on this chip, or row would clip below iconWrap
      host:SetHidden(true)
      if ic.barTag then ic.barTag:SetHidden(true) end
      if ic.markTag then ic.markTag:SetHidden(true) end
      if ic.cap then ic.cap:SetHidden(true) end
      if ic.tick then ic.tick:SetHidden(true) end
    end
  end
  local showPaceLegend = false
  if ui.iconMarkerLine then
    ui.iconMarkerLine:SetHidden(false)
    if totalSkills > 0 then
      local note = ""
      if pages > 1 then note = "  ·  footer Next page (Square / Y)"
      elseif clipped then note = "  ·  layout clipped — icons shrunk to fit"
      elseif pressCount > totalSkills then
        note = string.format("  ·  %d presses vs %d timeline tokens", pressCount, totalSkills)
      end
      ui.iconMarkerLine:SetText(string.format(
        "Visible icons %d  ·  S %d · U %d  ·  bar swaps %d  ·  presses %d / timeline %d%s",
        math.min(#events, maxFit), swapPlaced or 0, ultPlaced or 0, totalSwaps,
        pressCount, totalSkills, note
      ))
      showPaceLegend = true
    elseif session.isDummy then
      ui.iconMarkerLine:SetText("|c888888No skill presses captured this parse|r")
      showPaceLegend = true
    else
      ui.iconMarkerLine:SetText("")
      ui.iconMarkerLine:SetHidden(true)
    end
  end
  if ui.iconPaceLine then
    if showPaceLegend then
      ui.iconPaceLine:SetHidden(false)
      ui.iconPaceLine:SetText("Top bar = cast pace. Tick = LA before the next skill. Further right = tighter gap.")
    else
      ui.iconPaceLine:SetText("")
      ui.iconPaceLine:SetHidden(true)
    end
  end

  local tips = buildPatternInsights(session)
  -- Prefer #1 diagnosis drill on line 1 when available
  local diag = buildParseDiagnosis(session)
  if diag and diag.opportunities and diag.opportunities[1] then
    ui.patterns[1]:SetText("|cFFCC66Best next:|r " .. (diag.opportunities[1].drill or tips[1] or ""))
    for i = 2, 4 do ui.patterns[i]:SetText(tips[i - 1] or "") end
  else
    for i = 1, 4 do ui.patterns[i]:SetText(tips[i] or "") end
  end
end

---------------------------------------------------------------------
-- Insights = coach interpretation layer (Phase 1 five sections)
-- 1 Diagnosis  2 Waste  3 Build contribution  4 Execution  5 Next Test
---------------------------------------------------------------------
local INSIGHT_DIAG_OPP = 3
local INSIGHT_WASTE_LINES = 8
local INSIGHT_BUILD_SRC = 6
local IB_SET_ROWS = 6
local IB_BROUGHT = 5
local IB_CP_STORY = 3
local IB_CP_ROWS = 4
local IB_POT_LINES = 3
local INSIGHT_BUILD_CP = 8 -- match Build & Sets so Soft stars like Backstabber stay visible
local INSIGHT_EXEC_LINES = 5 -- Phase 3 P0: exception lines + More: Rotation

local function buildNextTestStub(session, diag, syn, profile)
  -- Prefer full Phase 2 coach analysis when available
  local coach = buildCoachAnalysis(session, syn, diag, profile)
  if coach and coach.nextTest then return coach.nextTest, coach end
  return {
    title = "Hold build; refine execution",
    body = "Complete a parse to unlock Next Test guidance.",
    confidence = CONFIDENCE.INSUFFICIENT,
  }, coach
end

local function createInsightsUI(screen, mode)
  -- mode: "dps" | "build" — split for readability / room to grow
  mode = (mode == "build") and "build" or "dps"
  local storeKey = (mode == "build") and "insightsBuildUI" or "insightsDpsUI"
  if screen[storeKey] and not screen[storeKey]._v3180 then screen[storeKey] = nil end
  if screen[storeKey] then
    local existing = screen[storeKey]
    -- Lazy-add Next Test action line (2.5.3) without full rebuild
    if mode == "dps" and existing.nextPanel and not existing.nextAction then
      local pfx = "DM2StatsMenuInDps"
      existing.nextAction = makeDashLabel(existing.nextPanel, pfx .. "NextActV6", 12, 0.55, 0.92, 0.75, 1)
    end
    return existing
  end
  ensureContentHost(screen)
  local panel = screen.contentPanels and (
    (mode == "build") and screen.contentPanels.insightsBuild or screen.contentPanels.insightsDps
  )
  if not panel then return nil end
  local ui = {
    panel = panel,
    mode = mode,
    oppRows = {},
    wasteLines = {},
    buildSrcs = {},
    buildCps = {},
    execLines = {},
    ibSetRows = {},
    ibBrought = {},
    ibCpStory = {},
    ibCpRows = {},
    ibPot = {},
    _v3180 = true,
  }
  local pfx = (mode == "build") and "DM2StatsMenuInBld" or "DM2StatsMenuInDps"
  local rootName = pfx .. "Root"
  ui.root = WM:CreateControl(rootName, panel, CT_CONTROL)
  ui.root:SetAnchor(TOPLEFT, panel, TOPLEFT, 4, 2)
  stampForeground(ui.root, 55)

  ui.title = makeDashLabel(ui.root, pfx .. "Title", 18, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.title:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, 0)
  ui.title:SetText(mode == "build" and "INSIGHTS: BUILD  ·  contribution & fit" or "INSIGHTS: DPS  ·  diagnosis & next test")
  ui.meta = makeDashLabel(ui.root, pfx .. "Meta", 14, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.meta:SetAnchor(TOPLEFT, ui.title, BOTTOMLEFT, 0, 2)
  ui.profileBadge = makeDashLabel(ui.root, pfx .. "Profile", 13, 0.85, 0.78, 0.45, 1)
  ui.profileBadge:SetAnchor(TOPRIGHT, ui.root, TOPRIGHT, -4, 2)
  ui.assumption = makeDashLabel(ui.root, pfx .. "Assume", 13, 0.90, 0.82, 0.55, 1)
  ui.assumption:SetAnchor(TOPLEFT, ui.meta, BOTTOMLEFT, 0, 2)
  ui.assumption:SetMaxLineCount(2)

  ui.diagPanel = WM:CreateControl(pfx .. "Diag", ui.root, CT_CONTROL)
  local dbg = makeSectionFrame(ui.diagPanel, pfx .. "DiagBG", true)
  dbg:SetAnchorFill(ui.diagPanel)
  ui.diagTitle = makeDashLabel(ui.diagPanel, pfx .. "DiagTitleV6", 14, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.diagTitle:SetText("1  PARSE DIAGNOSIS")
  ui.headline = makeDashLabel(ui.diagPanel, pfx .. "HeadlineV6", 16, THEME.textR, THEME.textG, THEME.textB, 1)
  ui.primary = makeDashLabel(ui.diagPanel, pfx .. "PrimaryV6", 13, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.primary:SetMaxLineCount(2)
  ui.phase = makeDashLabel(ui.diagPanel, pfx .. "PhaseV6", 13, THEME.textR, THEME.textG, THEME.textB, 1)
  ui.limitsHdr = makeDashLabel(ui.diagPanel, pfx .. "LimitsHdrV6", 12, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.limitsHdr:SetText("Top limits (estimated recovery)")
  for i = 1, INSIGHT_DIAG_OPP do
    local row = WM:CreateControl(pfx .. "OppV6_" .. i, ui.diagPanel, CT_CONTROL)
    local rank = makeDashLabel(row, pfx .. "OppRankV6_" .. i, 13, THEME.titleR, THEME.titleG, THEME.titleB, 1)
    local title = makeDashLabel(row, pfx .. "OppNameV6_" .. i, 14, THEME.textR, THEME.textG, THEME.textB, 1)
    local est = makeDashLabel(row, pfx .. "OppEstV6_" .. i, 13, 0.95, 0.72, 0.35, 1)
    est:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    local ev = makeDashLabel(row, pfx .. "OppEvV6_" .. i, 12, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
    ui.oppRows[i] = { row = row, rank = rank, title = title, est = est, ev = ev }
  end

  ui.wastePanel = WM:CreateControl(pfx .. "WasteV6", ui.root, CT_CONTROL)
  local wbg = makeSectionFrame(ui.wastePanel, pfx .. "WasteBGV6", true)
  wbg:SetAnchorFill(ui.wastePanel)
  ui.wasteTitle = makeDashLabel(ui.wastePanel, pfx .. "WasteTitleV6", 14, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.wasteTitle:SetText("2  WASTED OR MISSING VALUE")
  for i = 1, INSIGHT_WASTE_LINES do
    ui.wasteLines[i] = makeDashLabel(ui.wastePanel, pfx .. "WasteL6_" .. i, 13, THEME.textR, THEME.textG, THEME.textB, 1)
  end

  ui.buildPanel = WM:CreateControl(pfx .. "BuildV6", ui.root, CT_CONTROL)
  local bbg = makeSectionFrame(ui.buildPanel, pfx .. "BuildBGV6", true)
  bbg:SetAnchorFill(ui.buildPanel)
  ui.buildTitle = makeDashLabel(ui.buildPanel, pfx .. "BuildTitleV6", 14, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.buildTitle:SetText(mode == "build" and "INSIGHTS: BUILD  ·  what you brought, and did it pay" or "3  BUILD CONTRIBUTION")
  ui.buildMix = makeDashLabel(ui.buildPanel, pfx .. "BuildMixV6", 12, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.buildFp = makeDashLabel(ui.buildPanel, pfx .. "BuildFpV6", 12, 0.85, 0.78, 0.45, 1)
  ui.buildSrcHdr = makeDashLabel(ui.buildPanel, pfx .. "BuildSrcHdrV6", 12, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.buildSrcHdr:SetText("Top damage sources")
  ui.buildCpHdr = makeDashLabel(ui.buildPanel, pfx .. "BuildCpHdrV6", 12, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.buildCpHdr:SetText("Champion Points (detail on Build & Sets)")
  for i = 1, INSIGHT_BUILD_SRC do
    local row = WM:CreateControl(pfx .. "BuildSrcV7_" .. i, ui.buildPanel, CT_CONTROL)
    local bg = makeSectionFrame(row, pfx .. "BuildSrcBgV7_" .. i, false)
    bg:SetAnchorFill(row)
    local rank = makeDashLabel(row, pfx .. "BuildSrcR7_" .. i, 12, THEME.titleR, THEME.titleG, THEME.titleB, 1)
    local chip = makeDashLabel(row, pfx .. "BuildSrcC7_" .. i, 12, THEME.frontR, THEME.frontG, THEME.frontB, 1)
    local name = makeDashLabel(row, pfx .. "BuildSrcN7_" .. i, 13, THEME.textR, THEME.textG, THEME.textB, 1)
    local share = makeDashLabel(row, pfx .. "BuildSrcS7_" .. i, 12, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
    share:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    ui.buildSrcs[i] = { row = row, bg = bg, rank = rank, chip = chip, name = name, share = share }
  end
  for i = 1, INSIGHT_BUILD_CP do
    local row = WM:CreateControl(pfx .. "BuildCpV7_" .. i, ui.buildPanel, CT_CONTROL)
    local bg = makeSectionFrame(row, pfx .. "BuildCpBgV7_" .. i, false)
    bg:SetAnchorFill(row)
    local fit = makeDashLabel(row, pfx .. "BuildCpF7_" .. i, 12, 0.45, 0.92, 0.55, 1)
    local name = makeDashLabel(row, pfx .. "BuildCpN7_" .. i, 13, THEME.textR, THEME.textG, THEME.textB, 1)
    local impact = makeDashLabel(row, pfx .. "BuildCpI7_" .. i, 12, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
    ui.buildCps[i] = { row = row, bg = bg, fit = fit, name = name, impact = impact }
  end

  -- 3.18.0 Insights: Build stacked sections (not the old two-column src/CP clone)
  if mode == "build" then
    ui.ibSetHdr = makeDashLabel(ui.buildPanel, pfx .. "IbSetHdr", 13, THEME.titleR, THEME.titleG, THEME.titleB, 1)
    ui.ibSetHdr:SetText("B  SETS")
    ui.ibSetNote = makeDashLabel(ui.buildPanel, pfx .. "IbSetNote", 11, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
    ui.ibSetNote:SetMaxLineCount(2)
    for i = 1, IB_SET_ROWS do
      local line = makeDashLabel(ui.buildPanel, pfx .. "IbSet" .. i, 12, THEME.textR, THEME.textG, THEME.textB, 1)
      ui.ibSetRows[i] = line
    end
    ui.ibBroughtHdr = makeDashLabel(ui.buildPanel, pfx .. "IbBrHdr", 13, THEME.titleR, THEME.titleG, THEME.titleB, 1)
    ui.ibBroughtHdr:SetText("C  WHAT YOU BROUGHT")
    for i = 1, IB_BROUGHT do
      ui.ibBrought[i] = makeDashLabel(ui.buildPanel, pfx .. "IbBr" .. i, 12, THEME.textR, THEME.textG, THEME.textB, 1)
    end
    ui.ibCpHdr = makeDashLabel(ui.buildPanel, pfx .. "IbCpHdr", 13, THEME.titleR, THEME.titleG, THEME.titleB, 1)
    ui.ibCpHdr:SetText("D  CHAMPION POINTS")
    for i = 1, IB_CP_STORY do
      ui.ibCpStory[i] = makeDashLabel(ui.buildPanel, pfx .. "IbCpS" .. i, 12, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
    end
    for i = 1, IB_CP_ROWS do
      local row = WM:CreateControl(pfx .. "IbCpR" .. i, ui.buildPanel, CT_CONTROL)
      local fit = makeDashLabel(row, pfx .. "IbCpF" .. i, 12, 0.45, 0.92, 0.55, 1)
      local name = makeDashLabel(row, pfx .. "IbCpN" .. i, 12, THEME.textR, THEME.textG, THEME.textB, 1)
      local impact = makeDashLabel(row, pfx .. "IbCpI" .. i, 12, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
      ui.ibCpRows[i] = { row = row, fit = fit, name = name, impact = impact }
    end
    ui.ibBarHdr = makeDashLabel(ui.buildPanel, pfx .. "IbBarHdr", 13, THEME.titleR, THEME.titleG, THEME.titleB, 1)
    ui.ibBarHdr:SetText("E  FRONT / BACK")
    ui.ibBarLine = makeDashLabel(ui.buildPanel, pfx .. "IbBarL", 12, THEME.textR, THEME.textG, THEME.textB, 1)
    ui.ibPotHdr = makeDashLabel(ui.buildPanel, pfx .. "IbPotHdr", 13, THEME.titleR, THEME.titleG, THEME.titleB, 1)
    ui.ibPotHdr:SetText("F  POTIONS")
    for i = 1, IB_POT_LINES do
      ui.ibPot[i] = makeDashLabel(ui.buildPanel, pfx .. "IbPot" .. i, 12, THEME.textR, THEME.textG, THEME.textB, 1)
    end
    ui.ibNextHdr = makeDashLabel(ui.buildPanel, pfx .. "IbNxHdr", 13, THEME.titleR, THEME.titleG, THEME.titleB, 1)
    ui.ibNextHdr:SetText("G  BUILD NEXT TEST")
    ui.ibNextHead = makeDashLabel(ui.buildPanel, pfx .. "IbNxH", 13, 0.98, 0.84, 0.40, 1)
    ui.ibNextBody = makeDashLabel(ui.buildPanel, pfx .. "IbNxB", 12, THEME.textR, THEME.textG, THEME.textB, 1)
    ui.ibNextBody:SetMaxLineCount(3)
    ui.ibFoot = makeDashLabel(ui.buildPanel, pfx .. "IbFoot", 11, 0.50, 0.50, 0.46, 1)
  end

  ui.execPanel = WM:CreateControl(pfx .. "ExecV6", ui.root, CT_CONTROL)
  local ebg = makeSectionFrame(ui.execPanel, pfx .. "ExecBGV6", true)
  ebg:SetAnchorFill(ui.execPanel)
  ui.execTitle = makeDashLabel(ui.execPanel, pfx .. "ExecTitleV6", 14, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.execTitle:SetText("4  EXECUTION")
  ui.execSummary = makeDashLabel(ui.execPanel, pfx .. "ExecSumV6", 13, THEME.textR, THEME.textG, THEME.textB, 1)
  for i = 1, INSIGHT_EXEC_LINES do
    ui.execLines[i] = makeDashLabel(ui.execPanel, pfx .. "ExecL6_" .. i, 13, THEME.textR, THEME.textG, THEME.textB, 1)
  end

  ui.nextPanel = WM:CreateControl(pfx .. "NextV6", ui.root, CT_CONTROL)
  local nbg = makeSectionFrame(ui.nextPanel, pfx .. "NextBGV6", true)
  nbg:SetAnchorFill(ui.nextPanel)
  ui.nextTitle = makeDashLabel(ui.nextPanel, pfx .. "NextTitleV6", 14, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.nextTitle:SetText("5  NEXT TEST")
  ui.nextHead = makeDashLabel(ui.nextPanel, pfx .. "NextHeadV6", 15, 0.98, 0.84, 0.40, 1)
  ui.nextBody = makeDashLabel(ui.nextPanel, pfx .. "NextBodyV6", 13, THEME.textR, THEME.textG, THEME.textB, 1)
  ui.nextBody:SetMaxLineCount(3)
  ui.nextAction = makeDashLabel(ui.nextPanel, pfx .. "NextActV6", 12, 0.55, 0.92, 0.75, 1)
  ui.disclaimer = makeDashLabel(ui.nextPanel, pfx .. "DiscV6", 11, 0.50, 0.50, 0.46, 1)

  -- Hide sections not for this mode (full room for larger type)
  if mode == "dps" then
    if ui.buildPanel then ui.buildPanel:SetHidden(true) end
  else
    if ui.diagPanel then ui.diagPanel:SetHidden(true) end
    if ui.wastePanel then ui.wastePanel:SetHidden(true) end
    if ui.execPanel then ui.execPanel:SetHidden(true) end
    if ui.nextPanel then ui.nextPanel:SetHidden(true) end
    if ui.buildPanel then ui.buildPanel:SetHidden(false) end
  end

  screen[storeKey] = ui
  return ui
end

local function layoutInsightsUI(ui, hostW, hostH)
  if not ui or not ui.root then return end
  local W = math.max(480, (hostW or 900) - 4)
  local H = math.max(400, (hostH or 700) - 4)
  ui.root:ClearAnchors()
  ui.root:SetAnchor(TOPLEFT, ui.panel, TOPLEFT, 2, 0)
  ui.root:SetDimensions(W, H)
  ui.title:SetWidth(math.floor(W * 0.62))
  ui.meta:SetWidth(math.floor(W * 0.92))
  if ui.assumption then
    ui.assumption:ClearAnchors()
    ui.assumption:SetAnchor(TOPLEFT, ui.meta, BOTTOMLEFT, 0, 2)
    ui.assumption:SetWidth(W - 8)
  end
  if ui.profileBadge then
    ui.profileBadge:ClearAnchors()
    ui.profileBadge:SetAnchor(TOPRIGHT, ui.root, TOPRIGHT, -4, 2)
    ui.profileBadge:SetWidth(math.floor(W * 0.36))
    ui.profileBadge:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  end

  -- Extra headroom so profile assumption line is not clipped by section #3 box
  local y0 = (ui.mode == "build") and 72 or 58
  local gap = 5
  local mode = ui.mode or "dps"
  local heights, panels
  if mode == "build" then
    -- Build page: one large contribution panel, start slightly lower
    heights = { H - y0 - 4 }
    panels = { ui.buildPanel }
    if ui.buildPanel then ui.buildPanel:SetHidden(false) end
  else
    -- DPS page: diagnosis, waste, execution, next test (no build)
    local weights = { 0.32, 0.28, 0.18, 0.22 }
    local avail = H - y0 - gap * 3 - 2
    heights = {}
    local sum = 0
    for i, w in ipairs(weights) do
      heights[i] = math.floor(avail * w)
      sum = sum + heights[i]
    end
    heights[1] = heights[1] + (avail - sum)
    panels = { ui.diagPanel, ui.wastePanel, ui.execPanel, ui.nextPanel }
  end

  local y = y0
  for i, p in ipairs(panels) do
    if p then
      p:ClearAnchors()
      p:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, y)
      p:SetDimensions(W, heights[i] or 100)
      y = y + (heights[i] or 100) + gap
    end
  end
  -- For dps mode, still need layout dimensions for build panel (hidden)
  if mode == "dps" and ui.buildPanel then
    ui.buildPanel:SetHidden(true)
  end
  -- Map heights for rest of layout that indexes heights[1..5]
  if mode == "dps" then
    -- reuse local heights as h1..h4; set dummies for old indices
    local h1, h2, h3, h4 = heights[1], heights[2], heights[3], heights[4]
    heights = { h1, h2, 0, h3, h4 }
  else
    heights = { 0, 0, heights[1], 0, 0 }
  end

  local dH = heights[1] or 0
  if mode ~= "build" and ui.diagPanel and not ui.diagPanel:IsHidden() then
  ui.diagTitle:ClearAnchors()
  ui.diagTitle:SetAnchor(TOPLEFT, ui.diagPanel, TOPLEFT, 10, 4)
  ui.diagTitle:SetWidth(W - 20)
  ui.headline:ClearAnchors()
  ui.headline:SetAnchor(TOPLEFT, ui.diagPanel, TOPLEFT, 12, 22)
  ui.headline:SetWidth(W - 24)
  ui.primary:ClearAnchors()
  ui.primary:SetAnchor(TOPLEFT, ui.diagPanel, TOPLEFT, 12, 42)
  ui.primary:SetWidth(W - 24)
  ui.phase:ClearAnchors()
  ui.phase:SetAnchor(TOPLEFT, ui.diagPanel, TOPLEFT, 12, 68)
  ui.phase:SetWidth(W - 24)
  ui.limitsHdr:ClearAnchors()
  ui.limitsHdr:SetAnchor(TOPLEFT, ui.diagPanel, TOPLEFT, 12, 88)
  ui.limitsHdr:SetWidth(W - 24)
  local oppTop = 104
  local oppH = math.max(20, math.floor((math.max(80, dH) - oppTop - 4) / INSIGHT_DIAG_OPP))
  local nameW = math.min(240, math.max(140, math.floor(W * 0.30)))
  local estW = 80
  for i = 1, INSIGHT_DIAG_OPP do
    local r = ui.oppRows[i]
    if r then
      r.row:ClearAnchors()
      r.row:SetAnchor(TOPLEFT, ui.diagPanel, TOPLEFT, 10, oppTop + (i - 1) * oppH)
      r.row:SetDimensions(W - 20, oppH - 1)
      r.rank:ClearAnchors()
      r.rank:SetAnchor(LEFT, r.row, LEFT, 0, 0)
      r.rank:SetWidth(18)
      r.title:ClearAnchors()
      r.title:SetAnchor(LEFT, r.row, LEFT, 20, 0)
      r.title:SetWidth(nameW)
      r.title:SetMaxLineCount(1)
      r.est:ClearAnchors()
      r.est:SetAnchor(LEFT, r.row, LEFT, 22 + nameW, 0)
      r.est:SetWidth(estW)
      r.ev:ClearAnchors()
      r.ev:SetAnchor(LEFT, r.row, LEFT, 28 + nameW + estW, 0)
      r.ev:SetWidth(math.max(120, W - 50 - nameW - estW))
      r.ev:SetMaxLineCount(1)
    end
  end

  ui.wasteTitle:ClearAnchors()
  ui.wasteTitle:SetAnchor(TOPLEFT, ui.wastePanel, TOPLEFT, 10, 4)
  ui.wasteTitle:SetWidth(W - 20)
  local wTop = 22
  local wRowH = math.max(18, math.floor((math.max(80, heights[2] or 100) - wTop - 4) / INSIGHT_WASTE_LINES))
  for i = 1, INSIGHT_WASTE_LINES do
    local line = ui.wasteLines[i]
    if line then
    line:ClearAnchors()
    line:SetAnchor(TOPLEFT, ui.wastePanel, TOPLEFT, 12, wTop + (i - 1) * wRowH)
    line:SetWidth(W - 24)
    line:SetMaxLineCount(1)
    end
  end
  end -- dps diagnosis/waste layout

  if ui.buildPanel and (mode == "build" or (heights[3] or 0) > 40) then
  ui.buildTitle:ClearAnchors()
  ui.buildTitle:SetAnchor(TOPLEFT, ui.buildPanel, TOPLEFT, 10, 4)
  ui.buildTitle:SetWidth(W - 20)
  ui.buildFp:ClearAnchors()
  ui.buildFp:SetAnchor(TOPLEFT, ui.buildPanel, TOPLEFT, 12, 22)
  ui.buildFp:SetWidth(W - 24)
  ui.buildMix:ClearAnchors()
  ui.buildMix:SetAnchor(TOPLEFT, ui.buildPanel, TOPLEFT, 12, 40)
  ui.buildMix:SetWidth(W - 24)

  if mode == "build" and ui.ibSetHdr then
    -- Hide the old two-column clone (Damage / Build & Sets overlap)
    if ui.buildSrcHdr then ui.buildSrcHdr:SetHidden(true) end
    if ui.buildCpHdr then ui.buildCpHdr:SetHidden(true) end
    for i = 1, INSIGHT_BUILD_SRC do
      if ui.buildSrcs[i] then ui.buildSrcs[i].row:SetHidden(true) end
    end
    for i = 1, INSIGHT_BUILD_CP do
      if ui.buildCps[i] then ui.buildCps[i].row:SetHidden(true) end
    end
    local y = 62
    local innerW = W - 24
    local function placeHdr(lbl, textY)
      if not lbl then return textY end
      lbl:ClearAnchors()
      lbl:SetAnchor(TOPLEFT, ui.buildPanel, TOPLEFT, 12, textY)
      lbl:SetWidth(innerW)
      return textY + 16
    end
    local function placeLine(lbl, textY, h)
      if not lbl then return textY end
      lbl:ClearAnchors()
      lbl:SetAnchor(TOPLEFT, ui.buildPanel, TOPLEFT, 14, textY)
      lbl:SetWidth(innerW - 4)
      lbl:SetMaxLineCount(1)
      return textY + (h or 16)
    end
    y = placeHdr(ui.ibSetHdr, y)
    y = placeLine(ui.ibSetNote, y, 28)
    if ui.ibSetNote then ui.ibSetNote:SetMaxLineCount(2) end
    for i = 1, IB_SET_ROWS do
      y = placeLine(ui.ibSetRows[i], y, 16)
    end
    y = y + 4
    y = placeHdr(ui.ibBroughtHdr, y)
    for i = 1, IB_BROUGHT do
      y = placeLine(ui.ibBrought[i], y, 16)
    end
    y = y + 4
    y = placeHdr(ui.ibCpHdr, y)
    for i = 1, IB_CP_STORY do
      y = placeLine(ui.ibCpStory[i], y, 16)
    end
    for i = 1, IB_CP_ROWS do
      local r = ui.ibCpRows[i]
      if r then
        r.row:ClearAnchors()
        r.row:SetAnchor(TOPLEFT, ui.buildPanel, TOPLEFT, 12, y)
        r.row:SetDimensions(innerW, 17)
        r.fit:ClearAnchors()
        r.fit:SetAnchor(LEFT, r.row, LEFT, 0, 0)
        r.fit:SetWidth(48)
        r.name:ClearAnchors()
        r.name:SetAnchor(LEFT, r.row, LEFT, 52, 0)
        r.name:SetWidth(math.max(80, math.floor(innerW * 0.32)))
        r.name:SetMaxLineCount(1)
        r.impact:ClearAnchors()
        r.impact:SetAnchor(LEFT, r.row, LEFT, 56 + math.max(80, math.floor(innerW * 0.32)), 0)
        r.impact:SetWidth(math.max(120, innerW - 140))
        r.impact:SetMaxLineCount(1)
        y = y + 18
      end
    end
    y = y + 4
    y = placeHdr(ui.ibBarHdr, y)
    y = placeLine(ui.ibBarLine, y, 18)
    y = y + 4
    y = placeHdr(ui.ibPotHdr, y)
    for i = 1, IB_POT_LINES do
      y = placeLine(ui.ibPot[i], y, 16)
    end
    y = y + 4
    y = placeHdr(ui.ibNextHdr, y)
    y = placeLine(ui.ibNextHead, y, 18)
    if ui.ibNextBody then
      ui.ibNextBody:ClearAnchors()
      ui.ibNextBody:SetAnchor(TOPLEFT, ui.buildPanel, TOPLEFT, 14, y)
      ui.ibNextBody:SetWidth(innerW - 4)
      ui.ibNextBody:SetMaxLineCount(3)
      y = y + 48
    end
    if ui.ibFoot then
      ui.ibFoot:ClearAnchors()
      ui.ibFoot:SetAnchor(BOTTOMLEFT, ui.buildPanel, BOTTOMLEFT, 12, -4)
      ui.ibFoot:SetWidth(innerW)
    end
  else
    local colGap = 12
    local leftW = math.floor((W - 28 - colGap) * 0.48)
    local rightX = 12 + leftW + colGap
    local rightW = W - rightX - 10
    ui.buildSrcHdr:ClearAnchors()
    ui.buildSrcHdr:SetAnchor(TOPLEFT, ui.buildPanel, TOPLEFT, 12, 62)
    ui.buildSrcHdr:SetWidth(leftW)
    ui.buildCpHdr:ClearAnchors()
    ui.buildCpHdr:SetAnchor(TOPLEFT, ui.buildPanel, TOPLEFT, rightX, 62)
    ui.buildCpHdr:SetText("Champion Points  ·  id = skill id")
    ui.buildCpHdr:SetWidth(rightW)
    local srcTop = 78
    local buildH = heights[3] or 200
    local srcH = math.max(28, math.min(40, math.floor((buildH - srcTop - 6) / INSIGHT_BUILD_SRC)))
    local cpH = math.max(22, math.min(srcH, math.floor((buildH - srcTop - 6) / INSIGHT_BUILD_CP)))
    for i = 1, INSIGHT_BUILD_SRC do
      local r = ui.buildSrcs[i]
      r.row:ClearAnchors()
      r.row:SetAnchor(TOPLEFT, ui.buildPanel, TOPLEFT, 10, srcTop + (i - 1) * srcH)
      r.row:SetDimensions(leftW - 4, srcH - 3)
      r.rank:ClearAnchors()
      r.rank:SetAnchor(LEFT, r.row, LEFT, 6, 0)
      r.rank:SetWidth(16)
      r.chip:ClearAnchors()
      r.chip:SetAnchor(LEFT, r.row, LEFT, 22, 0)
      r.chip:SetWidth(28)
      r.name:ClearAnchors()
      r.name:SetAnchor(LEFT, r.row, LEFT, 52, 0)
      r.name:SetWidth(math.max(60, leftW - 130))
      r.name:SetMaxLineCount(1)
      r.share:ClearAnchors()
      r.share:SetAnchor(RIGHT, r.row, RIGHT, -8, 0)
      r.share:SetWidth(64)
    end
    for i = 1, INSIGHT_BUILD_CP do
      local r = ui.buildCps[i]
      r.row:ClearAnchors()
      r.row:SetAnchor(TOPLEFT, ui.buildPanel, TOPLEFT, rightX, srcTop + (i - 1) * cpH)
      r.row:SetDimensions(rightW - 4, cpH - 2)
      r.fit:ClearAnchors()
      r.fit:SetAnchor(LEFT, r.row, LEFT, 6, 0)
      r.fit:SetWidth(48)
      local nW = math.max(80, math.floor(rightW * 0.34))
      r.name:ClearAnchors()
      r.name:SetAnchor(LEFT, r.row, LEFT, 56, 0)
      r.name:SetWidth(nW)
      r.name:SetMaxLineCount(1)
      r.impact:ClearAnchors()
      r.impact:SetAnchor(LEFT, r.row, LEFT, 60 + nW, 0)
      r.impact:SetWidth(math.max(100, rightW - 72 - nW))
      r.impact:SetMaxLineCount(1)
    end
  end
  end -- build panel layout

  if mode ~= "build" and ui.execPanel then
  ui.execTitle:ClearAnchors()
  ui.execTitle:SetAnchor(TOPLEFT, ui.execPanel, TOPLEFT, 10, 4)
  ui.execTitle:SetWidth(W - 20)
  ui.execSummary:ClearAnchors()
  ui.execSummary:SetAnchor(TOPLEFT, ui.execPanel, TOPLEFT, 12, 22)
  ui.execSummary:SetWidth(W - 24)
  local eTop = 40
  local eH = math.max(16, math.floor((math.max(60, heights[4] or 80) - eTop - 4) / INSIGHT_EXEC_LINES))
  for i = 1, INSIGHT_EXEC_LINES do
    local line = ui.execLines[i]
    if line then
    line:ClearAnchors()
    line:SetAnchor(TOPLEFT, ui.execPanel, TOPLEFT, 12, eTop + (i - 1) * eH)
    line:SetWidth(W - 24)
    line:SetMaxLineCount(1)
    end
  end

  ui.nextTitle:ClearAnchors()
  ui.nextTitle:SetAnchor(TOPLEFT, ui.nextPanel, TOPLEFT, 10, 4)
  ui.nextTitle:SetWidth(W - 20)
  ui.nextHead:ClearAnchors()
  ui.nextHead:SetAnchor(TOPLEFT, ui.nextPanel, TOPLEFT, 12, 22)
  ui.nextHead:SetWidth(W - 24)
  ui.nextBody:ClearAnchors()
  ui.nextBody:SetAnchor(TOPLEFT, ui.nextPanel, TOPLEFT, 12, 42)
  ui.nextBody:SetWidth(W - 24)
  if ui.nextAction then
    ui.nextAction:ClearAnchors()
    ui.nextAction:SetAnchor(BOTTOMLEFT, ui.nextPanel, BOTTOMLEFT, 12, -22)
    ui.nextAction:SetWidth(W - 24)
  end
  ui.disclaimer:ClearAnchors()
  ui.disclaimer:SetAnchor(BOTTOMLEFT, ui.nextPanel, BOTTOMLEFT, 12, -4)
  ui.disclaimer:SetWidth(W - 24)
  end -- exec/next layout
end

local function fillInsightsBuildPage(ui, session, syn, coach, profile)
  if not ui or not ui.ibSetHdr then return end
  syn = syn or {}
  coach = coach or {}
  local dur = tonumber(session.durationMs) or 0
  local total = tonumber(session.totalDamage) or 0

  -- Header: mix already on buildMix; fingerprint on buildFp. Cohort on mix suffix if needed.
  local cohort = buildFingerprintCohort(session)
  local thisDps = sessionAvgDps(session)
  if cohort and (tonumber(cohort.n) or 0) >= 2 and ui.buildFp then
    local delta = thisDps - (tonumber(cohort.medianDps) or thisDps)
    ui.buildFp:SetText(string.format(
      "Build ID %s  ·  cohort n=%d  median %s  best %s  this %s (%s vs median)",
      string.sub(tostring(cohort.fingerprint or ""), 1, 8),
      cohort.n,
      fmtDps(cohort.medianDps),
      fmtDps(cohort.bestDps),
      fmtDps(thisDps),
      fmtDpsDelta(delta)
    ))
  end
  if ui.buildMix then
    ui.buildMix:SetText("A  MIX  ·  " .. (syn.mixLine or "—"))
  end

  -- B. Sets (honest)
  if ui.ibSetNote then
    ui.ibSetNote:SetText(
      "Proc rows show observed set/proc damage. Buff-mediated sets (Rallying Cry, Shacklebreaker, many 5pc) have no damage event — Damage will not grow a proc row."
    )
  end
  local setRows = {}
  local dmgByName = {}
  if type(session.sets) == "table" then
    for _, ps in pairs(session.sets) do
      if type(ps) == "table" and ps.name then
        dmgByName[string.lower(tostring(ps.name))] = ps
      end
    end
  end
  local names = {}
  if type(session.equippedSets) == "table" then
    for _, n in ipairs(session.equippedSets) do names[#names + 1] = tostring(n) end
  end
  if #names == 0 then
    for _, si in ipairs(coach.setImpact or {}) do
      names[#names + 1] = tostring(si.name or "?")
    end
  end
  for _, name in ipairs(names) do
    local low = string.lower(name)
    local ps = dmgByName[low]
    local dmg = (ps and tonumber(ps.dmg)) or 0
    local hits = (ps and tonumber(ps.hits)) or 0
    local share = total > 0 and (dmg / total) or 0
    local dps = dur > 0 and (dmg / (dur / 1000)) or 0
    local buffUp, buffName = 0, nil
    if type(session.buffs) == "table" then
      for _, b in pairs(session.buffs) do
        if type(b) == "table" and b.name then
          local blow = string.lower(tostring(b.name))
          if low ~= "" and (string.find(blow, low, 1, true) or string.find(low, blow, 1, true)) then
            local up = dur > 0 and ((tonumber(b.activeMs) or 0) / dur) or 0
            if up > buffUp then buffUp, buffName = up, b.name end
          end
        end
      end
    end
    local line
    if dmg > 0 then
      line = string.format("%s  ·  %s  %s DPS  %s share  %s",
        displayName(name, 28), fmtInt(dmg), fmtDps(dps), fmtPct(share), "[Observed]")
    elseif buffUp > 0.02 then
      line = string.format("%s  ·  buff set / no damage event  ·  %s up %s  %s",
        displayName(name, 28), displayName(buffName or "buff", 22), fmtPct(buffUp),
        "[Observed uptime, no proc DPS]")
    else
      line = string.format("%s  ·  buff set / no damage event  %s",
        displayName(name, 36), "[Observed]")
    end
    setRows[#setRows + 1] = line
  end
  for i = 1, IB_SET_ROWS do
    if ui.ibSetRows[i] then
      ui.ibSetRows[i]:SetText(displayNamePlain(setRows[i] or (i == 1 and "(no equipped sets captured)" or ""), 110))
    end
  end

  -- C. What you brought
  local snap = session.playerStatsEnd or session.playerStats or {}
  local buffed = snap.buffed or {}
  local mundus = canonicalMundusName(session.mundus)
    or canonicalMundusName(snap.mundus)
    or session.mundus or "—"
  local food = (session.build and session.build.food) or session.food or "—"
  local foodStart = session.playerStatsStart and session.playerStatsStart.food
  local foodNote = ""
  if foodStart and tostring(foodStart) ~= "" and tostring(food) ~= tostring(foodStart) then
    foodNote = "  ·  food changed this pull"
  end
  local attrs = snap.attributes or (session.build and session.build.attributes) or {}
  local brought = {
    string.format("Mundus %s  ·  Food %s%s", tostring(mundus), displayName(tostring(food), 40), foodNote),
    string.format("Sheet crit %0.1f%%  ·  Pen phys %s  ·  Pen spell %s",
      (tonumber(buffed.critChance) or 0) * 100,
      fmtInt(buffed.penPhysical or 0),
      fmtInt(buffed.penSpell or 0)),
    string.format("Attributes  Mag %s  HP %s  Stam %s",
      tostring(attrs.magicka or "—"), tostring(attrs.health or "—"), tostring(attrs.stamina or "—")),
  }
  local support = nil
  if type(coach.wasteLines) == "table" then
    for _, ln in ipairs(coach.wasteLines) do
      if type(ln) == "string" and string.find(string.lower(ln), "support you brought", 1, true) then
        support = ln
        break
      end
    end
  end
  brought[#brought + 1] = support or "Support you brought: see Buffs for the full list."
  for i = 1, IB_BROUGHT do
    if ui.ibBrought[i] then
      ui.ibBrought[i]:SetText(displayNamePlain(brought[i] or "", 110))
    end
  end

  -- D. CP story + warfare rows
  local cps = syn.cps or {}
  local war, strongN, softN = {}, 0, 0
  local directPct = tonumber(syn.directPct) or 0
  local dotPct = tonumber(syn.dotPct) or 0
  for _, c in ipairs(cps) do
    if c.constellation ~= "fitness" then
      war[#war + 1] = c
      if c.fitKey == "strong" then strongN = strongN + 1 end
      if c.fitKey == "soft" then softN = softN + 1 end
    end
  end
  local story = {}
  story[1] = string.format(
    "Parse mix Direct %s · DoT %s · %d Strong · %d Soft of %d Warfare  (Fitness N/A on dummy)",
    fmtPct(directPct), fmtPct(dotPct), strongN, softN, #war
  )
  local pay, softNames = {}, {}
  for _, c in ipairs(war) do
    if c.fitKey == "strong" then pay[#pay + 1] = c.name end
    if c.fitKey == "soft" then softNames[#softNames + 1] = c.name end
  end
  if #pay > 0 then
    story[2] = string.format("Pays on this dummy: %s", table.concat(pay, ", "))
  else
    story[2] = "No Strong Warfare fit vs this parse mix."
  end
  if #softNames > 0 then
    story[3] = string.format("Soft vs this mix: %s — swap toward Direct/DoT/crit shape, then three parses.",
      table.concat(softNames, ", "))
  else
    story[3] = "No Soft Warfare star on this parse."
  end
  for i = 1, IB_CP_STORY do
    if ui.ibCpStory[i] then ui.ibCpStory[i]:SetText(displayNamePlain(story[i] or "", 110)) end
  end
  for i = 1, IB_CP_ROWS do
    local r = ui.ibCpRows[i]
    local c = war[i]
    if r then
      if c then
        r.row:SetHidden(false)
        r.fit:SetText(c.fitLabel or "?")
        local fr, fg, fb, fa = fitBadgeColor(c.fitKey)
        r.fit:SetColor(fr, fg, fb, fa or 1)
        r.name:SetText(displayName(c.name or "?", 28))
        local impact
        if c.marginalDps ~= nil then
          impact = string.format("#%s Eligible %s · A/B %s",
            c.rankTxt or tostring(i), fmtPct(c.eligiblePct or 0), fmtDpsDelta(c.marginalDps))
        else
          impact = string.format("#%s Eligible %s · %s",
            c.rankTxt or tostring(i), fmtPct(c.eligiblePct or 0), c.eligibleNote or c.reason or "")
        end
        r.impact:SetText(displayNamePlain(impact, 72))
      else
        r.row:SetHidden(true)
      end
    end
  end

  -- E. Front / back
  local frontDmg, backDmg = 0, 0
  if type(session.skills) == "table" then
    for id, sk in pairs(session.skills) do
      if type(sk) == "table" then
        local dmg = tonumber(sk.dmg) or 0
        if dmg > 0 then
          local bar = getSkillBar(session, tonumber(sk.id) or tonumber(id) or 0)
          if bar == "Front" then frontDmg = frontDmg + dmg
          elseif bar == "Back" then backDmg = backDmg + dmg end
        end
      end
    end
  end
  local barSum = frontDmg + backDmg
  local bs = session.barStats or {}
  local fMs = tonumber(bs.frontMs) or 0
  local bMs = tonumber(bs.backMs) or 0
  local dwell = fMs + bMs
  if ui.ibBarLine then
    ui.ibBarLine:SetText(string.format(
      "Dwell F %s / B %s   ·   Damage F %s / B %s",
      dwell > 0 and fmtPct(fMs / dwell) or "—",
      dwell > 0 and fmtPct(bMs / dwell) or "—",
      barSum > 0 and fmtPct(frontDmg / barSum) or "—",
      barSum > 0 and fmtPct(backDmg / barSum) or "—"
    ))
  end

  -- F. Potions
  local pot = session.potion
  if type(pot) ~= "table" or (tonumber(pot.uses) or 0) <= 0 and (tonumber(pot.coveredMs) or 0) <= 0 then
    if ui.ibPot[1] then
      ui.ibPot[1]:SetText("Needs a new parse after 3.18.0 — potion uses/coverage were not stored on older fights.")
    end
    if ui.ibPot[2] then ui.ibPot[2]:SetText("") end
    if ui.ibPot[3] then ui.ibPot[3]:SetText("") end
  else
    local cover = dur > 0 and math.min(1, (tonumber(pot.coveredMs) or 0) / dur) or 0
    local first = tonumber(pot.firstUseMs)
    local firstTxt = pot.prePot and "first use at pull (pre-pot)"
      or (first and string.format("first use +%0.1fs", first / 1000) or "")
    local conf = pot.estimated and "[Estimated — may be skill/set]" or "[Observed]"
    if session.isDummy then conf = "[Observed]" end
    if ui.ibPot[1] then
      ui.ibPot[1]:SetText(string.format(
        "%d use%s · %s · covered %s of the pull · %s  %s",
        tonumber(pot.uses) or 0,
        (tonumber(pot.uses) or 0) == 1 and "" or "s",
        pot.kind or "unknown",
        fmtPct(cover),
        firstTxt,
        conf
      ))
    end
    local st = pot.stats or {}
    if ui.ibPot[2] then
      ui.ibPot[2]:SetText(string.format(
        "Intellect %s · Endurance %s · Fortitude %s · Expedition %s",
        fmtPct(st.intellect or 0), fmtPct(st.endurance or 0),
        fmtPct(st.fortitude or 0), fmtPct(st.expedition or 0)
      ))
    end
    local uses = tonumber(pot.uses) or 0
    local expect = dur > 0 and math.floor(dur / 45000 + 0.15) or 0
    if dur >= 90000 and uses > 0 and uses < expect then
      local miss = math.max(0, (expect - uses) * 45)
      if ui.ibPot[3] then
        ui.ibPot[3]:SetText(string.format("possible missed window ~%ds  [Estimated]", miss))
      end
    elseif ui.ibPot[3] then
      ui.ibPot[3]:SetText("No potion DPS is claimed — coverage only.")
    end
  end

  -- G. Build next test (build-shaped rules only)
  local nxt = coach.nextTest
  local buildRules = {
    soft_cp = true, pen_waste = true, crit_overcap_risk = true, sample_size = true,
  }
  if nxt and buildRules[nxt.ruleId or ""] then
    if ui.ibNextHead then ui.ibNextHead:SetText(nxt.title or "") end
    if ui.ibNextBody then ui.ibNextBody:SetText(displayNamePlain(nxt.body or "", 240)) end
  elseif nxt then
    if ui.ibNextHead then ui.ibNextHead:SetText("Hold build; execution lives on Insights: DPS") end
    if ui.ibNextBody then
      ui.ibNextBody:SetText("No high-confidence gear/CP swap on this parse. Use Insights: DPS for weave / DoT / next test. Y still starts experiments from that page.")
    end
  else
    if ui.ibNextHead then ui.ibNextHead:SetText("") end
    if ui.ibNextBody then ui.ibNextBody:SetText("") end
  end
  if ui.ibFoot then
    ui.ibFoot:SetText("[Observed] measured this fight. [Estimated] heuristic. Outcome DPS is never changed by this page.")
  end
end

local function refreshInsightsUI(screen, session, mode)
  mode = (mode == "build") and "build" or "dps"
  local ui = createInsightsUI(screen, mode)
  if not ui then return end
  local hostW, hostH = layoutContentHost(screen)
  layoutInsightsUI(ui, hostW, hostH)
  local profile = getActiveContentProfile()
  if ui.profileBadge then
    ui.profileBadge:SetText(formatProfileBadge(profile))
  end
  if ui.assumption then
    ui.assumption:SetText(
      "Trial-prep profile: coach lines may assume organized tank/healer buffs "
        .. "(e.g. Major Breach, Crusher, Major Force). "
        .. "[Estimated] = uses those assumptions. [Observed] = measured this fight. "
        .. "Outcome DPS numbers are never changed by profile."
    )
  end

  if not session then
    ui.meta:SetText("No fight selected")
    if ui.headline then ui.headline:SetText("Complete a parse to unlock coach diagnosis.") end
    if ui.primary then ui.primary:SetText("") end
    if ui.phase then ui.phase:SetText("") end
    for i = 1, INSIGHT_DIAG_OPP do
      if ui.oppRows[i] then ui.oppRows[i].row:SetHidden(true) end
    end
    for i = 1, INSIGHT_WASTE_LINES do
      if ui.wasteLines[i] then ui.wasteLines[i]:SetText("") end
    end
    if ui.buildMix then ui.buildMix:SetText("") end
    if ui.buildFp then ui.buildFp:SetText("") end
    for i = 1, INSIGHT_BUILD_SRC do
      if ui.buildSrcs[i] then ui.buildSrcs[i].row:SetHidden(true) end
    end
    for i = 1, INSIGHT_BUILD_CP do
      if ui.buildCps[i] then ui.buildCps[i].row:SetHidden(true) end
    end
    if ui.execSummary then ui.execSummary:SetText("") end
    for i = 1, INSIGHT_EXEC_LINES do
      if ui.execLines[i] then ui.execLines[i]:SetText("") end
    end
    if ui.nextHead then ui.nextHead:SetText("") end
    if ui.nextBody then ui.nextBody:SetText("Parse a dummy or trial pull, then reopen Insights.") end
    if ui.nextAction then ui.nextAction:SetText("") end
    if ui.disclaimer then ui.disclaimer:SetText("") end
    return
  end

  local diag = buildParseDiagnosis(session)
  local syn = buildBuildSynergy(session)
  local coach = buildCoachAnalysis(session, syn, diag, profile)
  setSessionCoach(session, coach) -- menu-local cache only — never onto SV history
  local bench = diag.bench
  local benchNote = ""
  if bench and (bench.comparableCount or 0) >= 2 then
    benchNote = string.format("  ·  vs best %s  ·  avg %s (%d runs)",
      fmtDps(bench.personalBest), fmtDps(bench.recentAvg), bench.comparableCount)
  end
  ui.meta:SetText(string.format("%s  ·  %s  ·  weave %s%s",
    displayName(session.lastTargetName or "fight", 40),
    fmtDur(session.durationMs),
    fmtPct(getWeaveSuccessRatio(session)),
    benchNote))

  if ui.headline then ui.headline:SetText(diag.headline or "") end
  if ui.primary then ui.primary:SetText(diag.primaryLine or "") end
  local ph = diag.phases or {}
  if ui.phase then
    ui.phase:SetText(string.format(
      "Phases: Opener %s  ·  Sustained %s  ·  Late %s",
      fmtDps(ph.opener or 0), fmtDps(ph.sustained or 0), fmtDps(ph.execute or 0)
    ))
  end
  local opps = diag.opportunities or {}
  for i = 1, INSIGHT_DIAG_OPP do
    local r = ui.oppRows[i]
    local o = opps[i]
    if r then
      if o then
        r.row:SetHidden(false)
        r.rank:SetText(tostring(i) .. ".")
        r.title:SetText(displayName(o.title or "?", 40))
        r.est:SetText("~" .. fmtDps(o.estDps or 0))
        r.ev:SetText(displayName(o.evidence or "", 80))
      else
        r.row:SetHidden(i ~= 1 or #opps > 0)
        if i == 1 and #opps == 0 then
          r.row:SetHidden(false)
          r.rank:SetText("")
          r.title:SetText("No large estimated gaps on this parse")
          r.est:SetText("")
          r.ev:SetText("Run more dummies for personal-best comparison")
        end
      end
    end
  end

  -- §2 Waste — prefer coach lines (pen profile + crit/Force risk)
  local waste = coach.wasteLines or {}
  for i = 1, INSIGHT_WASTE_LINES do
    if ui.wasteLines[i] then
      ui.wasteLines[i]:SetText(displayName(waste[i] or "", 220))
    end
  end

  local build = session.build or session.buildEnd or session.buildStart
  if ui.buildFp then
    if build and build.fingerprint then
      ui.buildFp:SetText(string.format(
        "Build ID %s  ·  %s",
        build.fingerprint,
        displayName(build.fingerprintLabel or "", 80)
      ))
    else
      ui.buildFp:SetText("Build ID: " .. confidenceChip(CONFIDENCE.INSUFFICIENT) .. " — new parse after reload required")
    end
  end
  -- Mix + top set one-liner
  local setHint = ""
  if coach.setImpact and coach.setImpact[1] then
    local s1 = coach.setImpact[1]
    setHint = string.format(
      "  ·  Top set direct: %s %s DPS (%s)",
      displayName(s1.name, 28),
      fmtDps(s1.directDps or 0),
      fmtPct(s1.directShare or 0)
    )
  end
  if ui.buildMix then
    local mix = (syn.mixLine or syn.headline or "") .. setHint
    -- Phase 2.5 scaffold: CP A/B candidate when history has comparable champion diffs
    if coach.cpAbHint and coach.cpAbHint ~= "" then
      mix = mix .. "  ·  " .. coach.cpAbHint
    end
    ui.buildMix:SetText(mix)
  end
  if mode == "build" then
    pcall(fillInsightsBuildPage, ui, session, syn, coach, profile)
  end
  local sources = syn.topSources or {}
  for i = 1, INSIGHT_BUILD_SRC do
    local r = ui.buildSrcs[i]
    if not r then break end
    local s = sources[i]
    if s then
      r.row:SetHidden(false)
      r.rank:SetText(tostring(i) .. ".")
      local chip = s.chip or ""
      if chip == "" then
        if s.source == "Effect" then chip = "E"
        elseif s.source == "Set proc" then chip = "S"
        elseif s.source == "Ultimate" then chip = "U"
        elseif s.source == "Light attack" then chip = "LA"
        else chip = "·" end
      end
      r.chip:SetText("[" .. chip .. "]")
      local barForColor = nil
      if chip == "F" then barForColor = "Front"
      elseif chip == "B" then barForColor = "Back" end
      local cr, cg, cb, ca = sourceChipColor(chip, barForColor)
      r.chip:SetColor(cr, cg, cb, ca or 1)
      r.name:SetText(formatAbilityDisplay(s.name, s.id or s.abilityId, 48))
      r.share:SetText(string.format("%s %s", fmtPct(s.share or 0), s.kind or ""))
    else
      r.row:SetHidden(i ~= 1 or #sources > 0)
      if i == 1 and #sources == 0 then
        r.row:SetHidden(false)
        r.rank:SetText("")
        r.chip:SetText("")
        r.name:SetText("No skill damage recorded")
        r.share:SetText("")
      end
    end
  end
  local cps = syn.cps or {}
  for i = 1, INSIGHT_BUILD_CP do
    local r = ui.buildCps[i]
    local c = cps[i]
    if c then
      r.row:SetHidden(false)
      r.fit:SetText(c.fitLabel or "?")
      local fr, fg, fb, fa = fitBadgeColor(c.fitKey)
      r.fit:SetColor(fr, fg, fb, fa or 1)
      r.name:SetText(formatAbilityDisplay(c.name, c.id, 42))
      local impactTxt
      if c.fitKey == "na" or c.fitKey == "surv" then
        impactTxt = c.impact or c.eligibleNote or c.reason or ""
      elseif c.marginalDps ~= nil then
        impactTxt = string.format(
          "Eligible %s · A/B %s",
          fmtPct(c.eligiblePct or 0),
          fmtDpsDelta(c.marginalDps)
        )
      else
        impactTxt = string.format(
          "Eligible %s · %s",
          fmtPct(c.eligiblePct or 0),
          c.eligibleNote or c.reason or ""
        )
      end
      if c.rankTxt then impactTxt = "#" .. c.rankTxt .. " · " .. impactTxt end
      r.impact:SetText(displayNamePlain(impactTxt, 68))
    else
      r.row:SetHidden(i ~= 1 or #cps > 0)
      if i == 1 and #cps == 0 then
        r.row:SetHidden(false)
        r.fit:SetText("")
        r.name:SetText("(no champion bar stars)")
        r.impact:SetText("Open Champion bar once, then reload if empty")
      end
    end
  end

  -- Phase 3 P0: exception-driven execution summary
  ensurePhase3Summary(session)
  local ex = session.execSummary
  if ui.execSummary then
    local pace = M.SkillCastPace(session)
    local durSec = (tonumber(session.durationMs) or 0) / 1000
    local lostSec = (tonumber(pace.totalLostMs) or 0) / 1000
    local gain = (durSec > 0) and ((lostSec * sessionAvgDps(session)) / durSec) or 0
    if pace.samples >= 8 then
      ui.execSummary:SetText(string.format(
        "Pace %0.3f s/cast · %0.1fs to recapture · %s DPS at fight average",
        pace.medianLostMs / 1000, lostSec, fmtDpsDelta(gain)
      ))
    elseif pace.early >= 8 then
      ui.execSummary:SetText("Presses landed early, so cast pace is not comparable on this pull.")
    else
      ui.execSummary:SetText("4  ·  exception-driven (detail on Rotation)")
    end
  end
  local shown = 0
  if type(ex) == "table" and type(ex.lines) == "table" then
    for _, line in ipairs(ex.lines) do
      if shown >= INSIGHT_EXEC_LINES then break end
      shown = shown + 1
      if ui.execLines[shown] then
        ui.execLines[shown]:SetText(displayName(tostring(line), 200))
      end
    end
  end
  if shown == 0 then
    local weave = type(session.weave) == "table" and session.weave or {}
    if ui.execLines[1] then
      ui.execLines[1]:SetText(string.format(
        "Weave %s · Miss %d · Late %d · Fast %d  %s",
        fmtPct(getWeaveSuccessRatio(session)),
        tonumber(weave.missedCount) or 0,
        tonumber(weave.lateCount) or 0,
        tonumber(weave.tooFastCount) or 0,
        confidenceChip(CONFIDENCE.OBSERVED)
      ))
      shown = 1
    end
  end
  for i = shown + 1, INSIGHT_EXEC_LINES do
    if ui.execLines[i] then ui.execLines[i]:SetText("") end
  end

  local nxt = coach.nextTest or select(1, buildNextTestStub(session, diag, syn, profile))
  if ui.nextHead then ui.nextHead:SetText(nxt.title or "") end
  if ui.nextBody then
    local body = nxt.body or ""
    if session.experimentRun and type(session.experimentRun) == "table" then
      body = body .. string.format(
        "  ·  This parse = experiment run %s",
        tostring(session.experimentRun.runIndex or "?")
      )
    end
    ui.nextBody:SetText(body)
  end
  if ui.nextAction then
    local expNow = getActiveExperiment()
    local hint
    if expNow then
      local n = type(expNow.runs) == "table" and #expNow.runs or 0
      local need = tonumber(expNow.targetRuns) or 3
      if expNow.completed then
        hint = string.format("|c66FF88EXP DONE %d/%d|r  ·  footer A/× : Clear experiment", n, need)
      else
        hint = string.format("|cFFCC66EXP ON %d/%d|r  ·  %s  ·  footer A/× : End experiment",
          n, need, displayName(expNow.title or "test", 40))
      end
    else
      hint = nxt.actionHint or ""
      if hint == "" or string.find(hint, "Y:", 1, true) then
        if nxt.ruleId and nxt.ruleId ~= "sample_size" then
          hint = "Footer |c66FF88A / ×|r : Start experiment (3 parses) — state shows here when ON"
        else
          hint = ""
        end
      end
    end
    ui.nextAction:SetText(hint or "")
  end
  local discParts = {}
  if diag.disclaimer then discParts[#discParts + 1] = diag.disclaimer end
  if syn and syn.disclaimer then discParts[#discParts + 1] = syn.disclaimer end
  discParts[#discParts + 1] = profile.note or ""
  if ui.disclaimer then ui.disclaimer:SetText(table.concat(discParts, "  ·  ")) end
end

---------------------------------------------------------------------
-- History redesign: fight cards → trend bars (middle) → comparison table
---------------------------------------------------------------------
local function createHistoryUI(screen)
  if screen.historyUI and not screen.historyUI._v3120 then screen.historyUI = nil end
  if screen.historyUI then
    -- Lazy-add 2.5.5 cohort strip without recreating the whole history tree
    if not screen.historyUI.cohort and screen.historyUI.root and screen.historyUI.subtitle then
      local c = makeDashLabel(screen.historyUI.root, "DM2StatsMenuHistCohortV10", 12, 0.85, 0.78, 0.45, 1)
      c:SetAnchor(TOPLEFT, screen.historyUI.subtitle, BOTTOMLEFT, 0, 1)
      screen.historyUI.cohort = c
    end
    return screen.historyUI
  end
  ensureContentHost(screen)
  local panel = screen.contentPanels and screen.contentPanels.history
  if not panel then return nil end
  local ui = {
    panel = panel,
    metrics = {
      { key = "dps", label = "DPS" },
      { key = "crit", label = "CRIT" },
      { key = "weave", label = "WEAVE" },
    },
    metricRows = {},
    cards = {},
    parseHdrs = {},
    compHdr = {},
    compRows = {},
    _v3120 = true,
  }

  ui.root = WM:CreateControl("DM2StatsMenuHistRootV9", panel, CT_CONTROL)
  ui.root:SetAnchor(TOPLEFT, panel, TOPLEFT, 8, 4)
  stampForeground(ui.root, 55)
  ui.title = makeDashLabel(ui.root, "DM2StatsMenuHistTitleV9", 16, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  ui.title:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, 0)
  ui.title:SetText("HISTORY")
  ui.subtitle = makeDashLabel(ui.root, "DM2StatsMenuHistSubV9", 13, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.subtitle:SetAnchor(TOPLEFT, ui.title, BOTTOMLEFT, 0, 2)
  -- Phase 2.5.5: fingerprint cohort strip
  ui.cohort = makeDashLabel(ui.root, "DM2StatsMenuHistCohortV10", 12, 0.85, 0.78, 0.45, 1)
  ui.cohort:SetAnchor(TOPLEFT, ui.subtitle, BOTTOMLEFT, 0, 1)

  -- 1) Fight cards (top) — single-line: # tag target | crit weave dur when | dps
  ui.listPanel = WM:CreateControl("DM2StatsMenuHistListV9", ui.root, CT_CONTROL)
  local lbg = makeSectionFrame(ui.listPanel, "DM2StatsMenuHistListBGV9", true)
  lbg:SetAnchorFill(ui.listPanel)
  ui.histTitle = makeDashLabel(ui.listPanel, "DM2StatsMenuHistListTitleV9", 13, THEME.titleR, THEME.titleG, THEME.titleB, 0.95)
  ui.histTitle:SetAnchor(TOPLEFT, ui.listPanel, TOPLEFT, 10, 6)
  ui.histTitle:SetText("RECENT FIGHTS  ·  L2 older  ·  R2 newer")
  for i = 1, TREND_HIST_LINES do
    local card = WM:CreateControl("DM2StatsMenuHistCardV9_" .. i, ui.listPanel, CT_CONTROL)
    local bg = makeSectionFrame(card, "DM2StatsMenuHistCardBGV9_" .. i, false)
    bg:SetAnchorFill(card)
    local sel = WM:CreateControl("DM2StatsMenuHistCardSelV9_" .. i, card, CT_BACKDROP)
    sel:SetCenterColor(0.35, 0.85, 0.95, 0.95)
    sel:SetEdgeColor(0, 0, 0, 0)
    sel:SetAnchor(TOPLEFT, card, TOPLEFT, 0, 0)
    sel:SetDimensions(5, 40)
    stampForeground(sel, 110)
    local num = makeDashLabel(card, "DM2StatsMenuHistCardNumV9_" .. i, 15, 0.55, 0.95, 1.0, 1)
    local tag = makeDashLabel(card, "DM2StatsMenuHistCardTagV9_" .. i, 12, 1.0, 0.88, 0.45, 1)
    local target = makeDashLabel(card, "DM2StatsMenuHistCardTgtV9_" .. i, 15, THEME.textR, THEME.textG, THEME.textB, 1)
    target:SetMaxLineCount(1)
    local crit = makeDashLabel(card, "DM2StatsMenuHistCardCritV9_" .. i, 13, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
    crit:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    local weave = makeDashLabel(card, "DM2StatsMenuHistCardWvV9_" .. i, 13, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
    weave:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    local dur = makeDashLabel(card, "DM2StatsMenuHistCardDurV9_" .. i, 13, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
    dur:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    local when = makeDashLabel(card, "DM2StatsMenuHistCardWhenV9_" .. i, 12, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
    when:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    local dps = makeDashLabel(card, "DM2StatsMenuHistCardDpsV9_" .. i, 18, 0.95, 0.82, 0.45, 1)
    dps:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    ui.cards[i] = {
      card = card, bg = bg, sel = sel, num = num, tag = tag, target = target,
      crit = crit, weave = weave, dur = dur, when = when, dps = dps,
    }
  end

  -- 2) Trend bars — fight # once above columns; values centered on bars
  ui.trendPanel = WM:CreateControl("DM2StatsMenuHistTrendV9", ui.root, CT_CONTROL)
  local tbg = makeSectionFrame(ui.trendPanel, "DM2StatsMenuHistTrendBGV9", true)
  tbg:SetAnchorFill(ui.trendPanel)
  ui.trendTitle = makeDashLabel(ui.trendPanel, "DM2StatsMenuHistTrendTitleV9", 13, THEME.titleR, THEME.titleG, THEME.titleB, 0.95)
  ui.trendTitle:SetAnchor(TOPLEFT, ui.trendPanel, TOPLEFT, 10, 4)
  ui.trendTitle:SetText("DUMMY TRENDS  ·  newest → oldest  ·  value mid-bar  ·  left # = latest dummy")
  ui.parseHdrRow = WM:CreateControl("DM2StatsMenuHistParseHdrV9", ui.trendPanel, CT_CONTROL)
  for j = 1, TREND_SPARK_MAX_BARS do
    ui.parseHdrs[j] = makeDashLabel(ui.parseHdrRow, "DM2StatsMenuHistParseHdrLblV9_" .. j, 11, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
    ui.parseHdrs[j]:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    ui.parseHdrs[j]:SetHidden(true)
  end
  for i, def in ipairs(ui.metrics) do
    local row = WM:CreateControl("DM2StatsMenuHistMetricV9_" .. i, ui.trendPanel, CT_CONTROL)
    local label = makeDashLabel(row, "DM2StatsMenuHistMetricLabelV9_" .. def.key, 13, THEME.titleR, THEME.titleG, THEME.titleB, 1)
    label:SetAnchor(LEFT, row, LEFT, 0, 0)
    label:SetText(def.label)
    local latest = makeDashLabel(row, "DM2StatsMenuHistMetricLatestV9_" .. def.key, 14, THEME.textR, THEME.textG, THEME.textB, 1)
    latest:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    local wrap, bars = createSparkBarPool(row, "DM2StatsMenuHistSparkV9_" .. def.key, TREND_SPARK_MAX_BARS)
    local barLabels = {}
    for j = 1, TREND_SPARK_MAX_BARS do
      barLabels[j] = makeDashLabel(row, "DM2StatsMenuHistSparkLblV9_" .. def.key .. j, 11, THEME.textR, THEME.textG, THEME.textB, 1)
      barLabels[j]:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
      barLabels[j]:SetHidden(true)
    end
    ui.metricRows[i] = {
      row = row, label = label, latest = latest, wrap = wrap, bars = bars,
      barLabels = barLabels, key = def.key,
    }
  end

  -- 3) Comparison table (bottom)
  ui.compPanel = WM:CreateControl("DM2StatsMenuHistCompV9", ui.root, CT_CONTROL)
  local cbg = makeSectionFrame(ui.compPanel, "DM2StatsMenuHistCompBGV9", true)
  cbg:SetAnchorFill(ui.compPanel)
  ui.compTitle = makeDashLabel(ui.compPanel, "DM2StatsMenuHistCompTitleV9", 13, THEME.titleR, THEME.titleG, THEME.titleB, 0.95)
  ui.compTitle:SetAnchor(TOPLEFT, ui.compPanel, TOPLEFT, 10, 4)
  ui.compTitle:SetText("DUMMY COMPARISON  ·  each column = one parse  ·  left (#1) = newest  ·  right = older")
  ui.compCorner = makeDashLabel(ui.compPanel, "DM2StatsMenuHistCompCornerV9", 12, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  ui.compCorner:SetText("Metric")
  for c = 1, COMP_COLS do
    ui.compHdr[c] = makeDashLabel(ui.compPanel, "DM2StatsMenuHistCompHdrV9_" .. c, 12, THEME.titleR, THEME.titleG, THEME.titleB, 1)
    ui.compHdr[c]:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  end
  for r = 1, COMP_METRICS do
    local row = { label = nil, cells = {} }
    row.label = makeDashLabel(ui.compPanel, "DM2StatsMenuHistCompLabV9_" .. r, 13, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
    for c = 1, COMP_COLS do
      local cell = makeDashLabel(ui.compPanel, "DM2StatsMenuHistCompCellV9_" .. r .. "_" .. c, 13, THEME.textR, THEME.textG, THEME.textB, 1)
      cell:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
      row.cells[c] = cell
    end
    ui.compRows[r] = row
  end

  screen.historyUI = ui
  return ui
end

local function layoutHistoryUI(ui, hostW, hostH)
  if not ui or not ui.root then return end
  local W = math.max(480, (hostW or 900) - 8)
  local H = math.max(400, (hostH or 700) - 8)
  ui.root:ClearAnchors()
  ui.root:SetAnchor(TOPLEFT, ui.panel, TOPLEFT, 8, 4)
  ui.root:SetDimensions(W, H)
  ui.title:SetWidth(W)
  ui.subtitle:SetWidth(W)
  if ui.cohort then ui.cohort:SetWidth(W) end

  -- Vertical split: cards ~34% | trends ~30% | table ~rest
  -- Extra headroom for cohort strip under subtitle
  local y0 = 58
  local listH = math.floor((H - y0) * 0.34)
  if listH < 140 then listH = 140 end
  local trendH = math.floor((H - y0) * 0.30)
  if trendH < 130 then trendH = 130 end
  local compH = H - y0 - listH - trendH - 12
  if compH < 120 then
    listH = H - y0 - trendH - 132
    compH = 120
  end

  ui.listPanel:ClearAnchors()
  ui.listPanel:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, y0)
  ui.listPanel:SetDimensions(W, listH)
  ui.histTitle:SetWidth(W - 20)
  local cardH = math.floor((listH - 30) / TREND_HIST_LINES)
  if cardH < 32 then cardH = 32 end
  if cardH > 44 then cardH = 44 end
  -- Single-line card: # | tag | target ........ | crit | weave | dur | when | dps
  local dpsW, whenW, durW, weaveW, critW = 88, 90, 56, 64, 64
  local rightPad = 12
  for i = 1, TREND_HIST_LINES do
    local c = ui.cards[i]
    if c and c.card then
      c.card:ClearAnchors()
      c.card:SetAnchor(TOPLEFT, ui.listPanel, TOPLEFT, 8, 26 + (i - 1) * cardH)
      c.card:SetDimensions(W - 16, cardH - 4)
      c.sel:SetDimensions(5, cardH - 8)
      local midY = math.floor((cardH - 8) / 2) - 8
      c.num:ClearAnchors()
      c.num:SetAnchor(TOPLEFT, c.card, TOPLEFT, 12, midY)
      c.num:SetWidth(40)
      c.tag:ClearAnchors()
      c.tag:SetAnchor(TOPLEFT, c.card, TOPLEFT, 52, midY + 2)
      c.tag:SetWidth(58)
      c.dps:ClearAnchors()
      c.dps:SetAnchor(TOPRIGHT, c.card, TOPRIGHT, -rightPad, midY - 2)
      c.dps:SetWidth(dpsW)
      c.when:ClearAnchors()
      c.when:SetAnchor(TOPRIGHT, c.card, TOPRIGHT, -(rightPad + dpsW + 6), midY + 1)
      c.when:SetWidth(whenW)
      c.dur:ClearAnchors()
      c.dur:SetAnchor(TOPRIGHT, c.card, TOPRIGHT, -(rightPad + dpsW + whenW + 12), midY + 1)
      c.dur:SetWidth(durW)
      c.weave:ClearAnchors()
      c.weave:SetAnchor(TOPRIGHT, c.card, TOPRIGHT, -(rightPad + dpsW + whenW + durW + 18), midY + 1)
      c.weave:SetWidth(weaveW)
      c.crit:ClearAnchors()
      c.crit:SetAnchor(TOPRIGHT, c.card, TOPRIGHT, -(rightPad + dpsW + whenW + durW + weaveW + 24), midY + 1)
      c.crit:SetWidth(critW)
      local targetRightReserve = rightPad + dpsW + whenW + durW + weaveW + critW + 40
      c.target:ClearAnchors()
      c.target:SetAnchor(TOPLEFT, c.card, TOPLEFT, 118, midY)
      c.target:SetWidth(math.max(120, (W - 16) - 118 - targetRightReserve))
    end
  end

  local trendY = y0 + listH + 6
  ui.trendPanel:ClearAnchors()
  ui.trendPanel:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, trendY)
  ui.trendPanel:SetDimensions(W, trendH)
  ui.trendTitle:SetWidth(W - 20)
  local parseHdrH = 16
  -- More left room for metric label + "latest" value; bars slightly narrower.
  local barLeft = 168
  local barAreaW = math.floor((W - 24 - barLeft) * 0.88)
  ui.parseHdrRow:ClearAnchors()
  ui.parseHdrRow:SetAnchor(TOPLEFT, ui.trendPanel, TOPLEFT, barLeft + 12, 20)
  ui.parseHdrRow:SetDimensions(barAreaW, parseHdrH)
  local metricsTop = 20 + parseHdrH + 2
  local rowH = math.floor((trendH - metricsTop - 4) / 3)
  if rowH < 32 then rowH = 32 end
  for i, row in ipairs(ui.metricRows) do
    row.row:ClearAnchors()
    row.row:SetAnchor(TOPLEFT, ui.trendPanel, TOPLEFT, 12, metricsTop + (i - 1) * rowH)
    row.row:SetDimensions(W - 24, rowH - 2)
    row.label:SetWidth(56)
    row.latest:ClearAnchors()
    row.latest:SetAnchor(LEFT, row.row, LEFT, 58, 0)
    row.latest:SetWidth(96)
    row.wrap:ClearAnchors()
    row.wrap:SetAnchor(LEFT, row.row, LEFT, barLeft - 12, 0)
    local barAreaH = math.max(20, rowH - 8)
    row.wrap:SetDimensions(barAreaW, barAreaH)
  end
  ui._histBarLeft = barLeft
  ui._histBarAreaW = barAreaW

  local compY = trendY + trendH + 6
  ui.compPanel:ClearAnchors()
  ui.compPanel:SetAnchor(TOPLEFT, ui.root, TOPLEFT, 0, compY)
  ui.compPanel:SetDimensions(W, compH)
  ui.compTitle:SetWidth(W - 20)

  -- Slightly wider label so "vs Fight #2" fits without wrapping
  local labelW = math.min(118, math.floor(W * 0.15))
  local colW = math.floor((W - 28 - labelW) / COMP_COLS)
  local top = 24
  ui.compCorner:ClearAnchors()
  ui.compCorner:SetAnchor(TOPLEFT, ui.compPanel, TOPLEFT, 12, top)
  ui.compCorner:SetWidth(labelW)
  for c = 1, COMP_COLS do
    local hdr = ui.compHdr[c]
    if hdr then
      hdr:ClearAnchors()
      hdr:SetAnchor(TOPLEFT, ui.compPanel, TOPLEFT, 12 + labelW + (c - 1) * colW, top)
      hdr:SetWidth(colW - 6)
    end
  end
  local rh = math.floor((compH - top - 20) / COMP_METRICS)
  if rh < 16 then rh = 16 end
  if rh > 22 then rh = 22 end
  for r = 1, COMP_METRICS do
    local row = ui.compRows[r]
    if row then
      local y = top + 18 + (r - 1) * rh
      row.label:ClearAnchors()
      row.label:SetAnchor(TOPLEFT, ui.compPanel, TOPLEFT, 12, y)
      row.label:SetWidth(labelW)
      if row.label.SetMaxLineCount then row.label:SetMaxLineCount(1) end
      local isDeltaRow = (r == COMP_METRICS) -- last row = vs Fight #2 notes
      for c = 1, COMP_COLS do
        local cell = row.cells[c]
        if cell then
          cell:ClearAnchors()
          if isDeltaRow and c == 1 then
            -- Right-anchored so long note grows left; leave a pocket for col2 "←"
            local noteW = math.min(colW * 2 - 28, colW + math.floor(colW * 0.55))
            cell:SetAnchor(TOPRIGHT, ui.compPanel, TOPLEFT, 12 + labelW + colW - 10, y)
            cell:SetWidth(noteW)
            cell:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
          else
            cell:SetAnchor(TOPLEFT, ui.compPanel, TOPLEFT, 12 + labelW + (c - 1) * colW, y)
            cell:SetWidth(colW - 6)
            cell:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
          end
          if cell.SetMaxLineCount then cell:SetMaxLineCount(1) end
        end
      end
    end
  end
end

local function refreshHistoryUI(screen)
  local ui = createHistoryUI(screen)
  if not ui then return end
  local hostW, hostH = layoutContentHost(screen)
  layoutHistoryUI(ui, hostW, hostH)

  local trends = collectDummyTrendParses(TREND_MAX_COLS)
  local liveCount = historyCount()
  local selected = liveCount > 0 and historyAt(historyOffset) or nil
  if liveCount <= 0 then
    ui.subtitle:SetText("No fights in history yet — complete a parse")
  else
    local exp = getActiveExperiment()
    local expBit = ""
    if exp then
      local rn = type(exp.runs) == "table" and #exp.runs or 0
      local need = tonumber(exp.targetRuns) or 3
      expBit = exp.completed
        and string.format(" · experiment done %d/%d", rn, need)
        or string.format(" · experiment %d/%d", rn, need)
    end
    ui.subtitle:SetText(string.format(
      "%d fights stored · offset %d · %d dummy(s) for trends/compare · L2/R2 to walk%s",
      liveCount, historyOffset, #trends, expBit
    ))
  end
  if ui.cohort then
    local cohort = selected and buildFingerprintCohort(selected) or nil
    if cohort and cohort.n >= 2 then
      ui.cohort:SetText(string.format(
        "Build %s · %d comparable dummy parses · median %s · best %s · worst %s · weave median %s",
        string.sub(tostring(cohort.fingerprint), 1, 8),
        cohort.n,
        fmtDps(cohort.medianDps),
        fmtDps(cohort.bestDps),
        fmtDps(cohort.worstDps),
        fmtPct(cohort.medianWeave)
      ))
    elseif cohort and cohort.n == 1 then
      ui.cohort:SetText(string.format(
        "Build %s · 1 dummy parse on this fingerprint — run more for median cohort",
        string.sub(tostring(cohort.fingerprint), 1, 8)
      ))
    else
      ui.cohort:SetText("Build cohort: need fingerprint on selected fight (new parse after build snapshot)")
    end
  end

  -- Cards — single row: # tag target | crit weave dur when | dps
  local cards = buildHistoryCards(historyOffset, TREND_HIST_LINES)
  for i = 1, TREND_HIST_LINES do
    local c = ui.cards[i]
    local d = cards[i]
    if c then
      if d then
        c.card:SetHidden(false)
        c.num:SetText(string.format("#%d", d.fightNo))
        c.tag:SetText(d.tag or "")
        local tagStr = tostring(d.tag or "")
        if string.sub(tagStr, 1, 3) == "EXP" then
          c.tag:SetColor(0.45, 0.95, 0.70, 1)
        elseif d.isDummy then
          c.tag:SetColor(1.0, 0.88, 0.45, 1)
        else
          c.tag:SetColor(0.70, 0.78, 0.90, 1)
        end
        c.target:SetText(d.target or "?")
        if c.crit then c.crit:SetText(d.crit or "—") end
        if c.weave then c.weave:SetText(d.weave or "—") end
        if c.dur then c.dur:SetText(d.dur or "—") end
        if c.when then c.when:SetText(d.when or "—") end
        c.dps:SetText(d.dps or "—")
        if d.selected then
          c.sel:SetHidden(false)
          c.bg:SetCenterColor(0.12, 0.18, 0.22, 0.75)
          c.bg:SetEdgeColor(0.40, 0.80, 0.90, 0.65)
          c.num:SetColor(0.55, 0.98, 1.0, 1)
        else
          c.sel:SetHidden(true)
          c.bg:SetCenterColor(THEME.cardR, THEME.cardG, THEME.cardB, THEME.cardA * 0.55)
          c.bg:SetEdgeColor(THEME.cardEdgeR, THEME.cardEdgeG, THEME.cardEdgeB, THEME.cardEdgeA * 0.7)
          c.num:SetColor(0.72, 0.78, 0.84, 1)
        end
      else
        c.card:SetHidden(true)
      end
    end
  end

  -- Trend bars: newest → oldest (same as comparison). #1 = newest.
  -- Left number = latest dummy value for that metric (not an average).
  local ordered = trends  -- already newest-first from collectDummyTrendParses
  local latest = trends[1]
  local fightCount = historyCount()
  local parseTags = {}
  for _, t in ipairs(ordered) do
    parseTags[#parseTags + 1] = string.format("#%d", fightNumberFromOffset(t.offset, fightCount))
  end
  local wrapWRef = ui._histBarAreaW or 200
  if wrapWRef < 40 then wrapWRef = 200 end
  local colCount = math.min(#ordered, TREND_SPARK_MAX_BARS)
  local barW = math.max(10, math.floor((wrapWRef - 4) / math.max(colCount, 1)) - 2)
  for j = 1, TREND_SPARK_MAX_BARS do
    local hdr = ui.parseHdrs and ui.parseHdrs[j]
    if hdr then
      if j <= colCount and parseTags[j] then
        hdr:ClearAnchors()
        hdr:SetAnchor(TOPLEFT, ui.parseHdrRow, TOPLEFT, (j - 1) * (barW + 2), 0)
        hdr:SetWidth(barW + 2)
        hdr:SetText(parseTags[j])
        hdr:SetHidden(false)
      else
        hdr:SetHidden(true)
      end
    end
  end
  for _, row in ipairs(ui.metricRows) do
    local wrapW = row.wrap:GetWidth() or wrapWRef
    if wrapW < 40 then wrapW = wrapWRef end
    local wrapH = row.wrap:GetHeight() or TREND_SPARK_BAR_MAX_H
    local values = {}
    local valueLabels = {}
    for _, t in ipairs(ordered) do
      if row.key == "dps" then
        values[#values + 1] = t.dps
        local d = tonumber(t.dps) or 0
        if d >= 1000 then
          valueLabels[#valueLabels + 1] = string.format("%.0fk", d / 1000)
        else
          valueLabels[#valueLabels + 1] = fmtDps(d)
        end
      elseif row.key == "crit" then
        values[#values + 1] = t.crit
        valueLabels[#valueLabels + 1] = string.format("%.0f%%", (t.crit or 0) * 100)
      else
        values[#values + 1] = t.weave
        valueLabels[#valueLabels + 1] = string.format("%.0f%%", (t.weave or 0) * 100)
      end
    end
    local barMaxH = math.max(12, wrapH - 4)
    layoutSparkBars(row.bars, row.wrap, values, wrapW, barMaxH, TREND_SPARK_MAX_BARS)
    local count = math.min(#values, TREND_SPARK_MAX_BARS, #(row.barLabels or {}))
    local thisBarW = math.max(10, math.floor((wrapW - 4) / math.max(count, 1)) - 2)
    for j = 1, TREND_SPARK_MAX_BARS do
      local lbl = row.barLabels and row.barLabels[j]
      if lbl then
        if j <= count and valueLabels[j] then
          lbl:ClearAnchors()
          lbl:SetAnchor(CENTER, row.wrap, BOTTOMLEFT,
            (j - 1) * (thisBarW + 2) + math.floor(thisBarW / 2),
            -math.floor(barMaxH / 2))
          lbl:SetWidth(thisBarW + 4)
          lbl:SetMaxLineCount(1)
          lbl:SetText(valueLabels[j])
          -- Dark text so values read on green/yellow bars
          lbl:SetColor(0.05, 0.05, 0.06, 1)
          lbl:SetHidden(false)
          stampForeground(lbl, 120)
        else
          lbl:SetHidden(true)
        end
      end
    end
    if latest then
      if row.key == "dps" then row.latest:SetText(fmtDps(latest.dps))
      elseif row.key == "crit" then row.latest:SetText(fmtPct(latest.crit))
      else row.latest:SetText(fmtPct(latest.weave)) end
    else
      row.latest:SetText("—")
    end
  end

  -- Comparison table
  local headers, rows = buildComparisonTable(COMP_COLS)
  for c = 1, COMP_COLS do
    local hdr = ui.compHdr[c]
    if hdr then
      if headers[c] then
        hdr:SetHidden(false)
        hdr:SetText(headers[c])
      else
        hdr:SetText("")
        hdr:SetHidden(true)
      end
    end
  end
  for r = 1, COMP_METRICS do
    local row = ui.compRows[r]
    local data = rows[r]
    if row then
      if data then
        row.label:SetHidden(false)
        row.label:SetText(data.label or "")
        for c = 1, COMP_COLS do
          local cell = row.cells[c]
          if cell then
            if data.cells and data.cells[c] then
              cell:SetHidden(false)
              cell:SetText(data.cells[c])
            else
              cell:SetText("")
              cell:SetHidden(true)
            end
          end
        end
      else
        row.label:SetHidden(true)
        for c = 1, COMP_COLS do
          if row.cells[c] then row.cells[c]:SetHidden(true) end
        end
      end
    end
  end
end

---------------------------------------------------------------------
-- Dashboard (2-col fight + build)
---------------------------------------------------------------------
local DASH_STAT_ROWS = 12
local DASH_KEYBUFF_ROWS = 1

local function createDashboardUI(screen)
  if screen.dashboardUI and screen.dashboardUI.panel and screen.dashboardUI._v3121 then
    return screen.dashboardUI
  end
  if screen.dashboardUI and not screen.dashboardUI._v3121 then
    screen.dashboardUI = nil
  end
  ensureContentHost(screen)
  local panel = screen.contentPanels and screen.contentPanels.dashboard
  if not panel then return nil end

  local dash = {
    panel = panel,
    cols = {},
    topSkills = {},
    barIcons = { front = {}, back = {} },
    gearLines = {},
    cpCols = { combat = {}, fitness = {}, craft = {} },
    cpColTitles = {},
    statRows = {},
    rotLines = {},
    _v3121 = true,
  }

  for index = 1, 2 do
    local col = WM:CreateControl("DM2StatsMenuDashCol" .. index, panel, CT_CONTROL)
    local bg = makeSectionFrame(col, "DM2StatsMenuDashColBG" .. index, true)
    bg:SetAnchorFill(col)
    local title = makeDashLabel(col, "DM2StatsMenuDashColTitle" .. index, 15, THEME.titleR, THEME.titleG, THEME.titleB, 1)
    title:SetAnchor(TOPLEFT, col, TOPLEFT, 12, 10)
    title:SetText(index == 1 and "FIGHT" or "BUILD")
    dash.cols[index] = { control = col, title = title }
  end

  local col1 = dash.cols[1].control
  local col2 = dash.cols[2].control

  dash.target = makeDashLabel(col1, "DM2StatsMenuDashTarget", 22, 0.95, 0.92, 0.86, 1)
  dash.target:SetAnchor(TOPLEFT, col1, TOPLEFT, 12, 40)

  dash.meta = makeDashLabel(col1, "DM2StatsMenuDashMeta", 15, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  dash.meta:SetAnchor(TOPLEFT, dash.target, BOTTOMLEFT, 0, 4)

  dash.dummyBadge = makeDashLabel(col1, "DM2StatsMenuDashDummy", 14, 1.0, 0.88, 0.45, 1)
  dash.dummyBadge:SetAnchor(TOPLEFT, dash.meta, BOTTOMLEFT, 0, 4)

  dash.heroDps = makeDashLabel(col1, "DM2StatsMenuDashHeroDps", 32, 0.95, 0.82, 0.45, 1)
  dash.heroDps:SetAnchor(TOPLEFT, col1, TOPLEFT, 12, 110)

  dash.heroSub = makeDashLabel(col1, "DM2StatsMenuDashHeroSub", 15, THEME.textR, THEME.textG, THEME.textB, 1)
  dash.heroSub:SetAnchor(TOPLEFT, dash.heroDps, BOTTOMLEFT, 0, 4)
  dash.heroSub:SetMaxLineCount(3)

  for i = 1, 3 do
    local line = makeDashLabel(col1, "DM2StatsMenuDashRot" .. i, 14, THEME.textR, THEME.textG, THEME.textB, 1)
    line:SetAnchor(TOPLEFT, col1, TOPLEFT, 12, 210 + ((i - 1) * 22))
    dash.rotLines[i] = line
  end

  dash.sparkTitle = makeDashLabel(col1, "DM2StatsMenuDashSparkTitle", 13, THEME.titleR, THEME.titleG, THEME.titleB, 0.95)
  dash.sparkTitle:SetAnchor(TOPLEFT, col1, TOPLEFT, 12, 290)
  dash.sparkTitle:SetText("DPS OVER TIME")

  local sparkWrap, sparkBars = createSparkBarPool(col1, "DM2StatsMenuDashSpark", SPARK_MAX_BARS)
  sparkWrap:SetAnchor(TOPLEFT, col1, TOPLEFT, 12, 312)
  dash.sparkWrap = sparkWrap
  dash.sparkBars = sparkBars

  dash.skillTitle = makeDashLabel(col1, "DM2StatsMenuDashSkillTitle", 13, THEME.titleR, THEME.titleG, THEME.titleB, 0.95)
  dash.skillTitle:SetAnchor(TOPLEFT, col1, TOPLEFT, 12, 380)
  dash.skillTitle:SetText("TOP DAMAGE SKILLS")

  for i = 1, 5 do
    local row = WM:CreateControl("DM2StatsMenuDashSkillRow" .. i, col1, CT_CONTROL)
    row:SetAnchor(TOPLEFT, col1, TOPLEFT, 12, 402 + ((i - 1) * 36))
    row:SetDimensions(360, 34)
    local icon = WM:CreateControl("DM2StatsMenuDashSkillIcon" .. i, row, CT_TEXTURE)
    icon:SetDimensions(DASH_TOP_SKILL_ICON, DASH_TOP_SKILL_ICON)
    icon:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 2)
    stampForeground(icon, 110)
    local nameLbl = makeDashLabel(row, "DM2StatsMenuDashSkillName" .. i, 15, THEME.textR, THEME.textG, THEME.textB, 1)
    nameLbl:SetAnchor(TOPLEFT, row, TOPLEFT, DASH_TOP_SKILL_ICON + 8, 0)
    local subLbl = makeDashLabel(row, "DM2StatsMenuDashSkillSub" .. i, 13, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
    subLbl:SetAnchor(TOPLEFT, nameLbl, BOTTOMLEFT, 0, 0)
    dash.topSkills[i] = { row = row, icon = icon, name = nameLbl, sub = subLbl }
  end

  dash.frontTitle = makeDashLabel(col2, "DM2StatsMenuDashFrontBar", 14, THEME.frontR, THEME.frontG, THEME.frontB, 1)
  dash.frontTitle:SetAnchor(TOPLEFT, col2, TOPLEFT, 12, 40)
  dash.frontTitle:SetText("FRONT BAR")

  dash.backTitle = makeDashLabel(col2, "DM2StatsMenuDashBackBar", 14, THEME.backR, THEME.backG, THEME.backB, 1)
  dash.backTitle:SetAnchor(TOPLEFT, col2, TOPLEFT, 12, 120)
  dash.backTitle:SetText("BACK BAR")

  dash.gearTitle = makeDashLabel(col2, "DM2StatsMenuDashGearTitleV3", 14, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  dash.gearTitle:SetAnchor(TOPLEFT, col2, TOPLEFT, 12, 210)
  dash.gearTitle:SetText("EQUIPPED SETS")

  for _, barKey in ipairs({ "front", "back" }) do
    local y = (barKey == "front") and 64 or 144
    for i = 1, 6 do
      local slotBg = WM:CreateControl("DM2StatsMenuDashV3" .. barKey .. "SlotBG" .. i, col2, CT_BACKDROP)
      slotBg:SetDimensions(BAR_ICON_SIZE + 4, BAR_ICON_SIZE + 4)
      slotBg:SetAnchor(TOPLEFT, col2, TOPLEFT, 12 + ((i - 1) * (BAR_ICON_SIZE + 8)), y)
      slotBg:SetCenterColor(0.14, 0.12, 0.09, 0.95)
      slotBg:SetEdgeColor(THEME.cardEdgeR, THEME.cardEdgeG, THEME.cardEdgeB, 0.75)
      stampBackground(slotBg, 4)
      local icon = WM:CreateControl("DM2StatsMenuDashV3" .. barKey .. "Icon" .. i, slotBg, CT_TEXTURE)
      icon:SetDimensions(BAR_ICON_SIZE, BAR_ICON_SIZE)
      icon:SetAnchor(CENTER, slotBg, CENTER, 0, 0)
      stampForeground(icon, 110)
      dash.barIcons[barKey][i] = { bg = slotBg, icon = icon }
    end
  end

  for i = 1, 4 do
    local line = makeDashLabel(col2, "DM2StatsMenuDashGearV3_" .. i, 14, THEME.textR, THEME.textG, THEME.textB, 1)
    line:SetAnchor(TOPLEFT, col2, TOPLEFT, 12, 236 + ((i - 1) * 20))
    dash.gearLines[i] = line
  end

  -- Mundus (activated stone — not a gear piece)
  dash.mundusTitle = makeDashLabel(col2, "DM2StatsMenuDashMundusTitle", 14, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  dash.mundusTitle:SetAnchor(TOPLEFT, col2, TOPLEFT, 12, 310)
  dash.mundusTitle:SetText("MUNDUS")
  dash.mundusLine = makeDashLabel(col2, "DM2StatsMenuDashMundusLine", 13, THEME.textR, THEME.textG, THEME.textB, 1)
  dash.mundusLine:SetAnchor(TOPLEFT, col2, TOPLEFT, 12, 328)

  -- Character stats — structured columns: Stat | Sheet | Temp | note
  dash.statsTitle = makeDashLabel(col2, "DM2StatsMenuDashStatsTitleV4", 14, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  dash.statsTitle:SetAnchor(TOPLEFT, col2, TOPLEFT, 12, 348)
  dash.statsTitle:SetText("CHAR STATS")
  dash.statsProv = makeDashLabel(col2, "DM2StatsMenuDashStatsProvV4", 10, 0.85, 0.78, 0.45, 1)
  dash.statsProv:SetAnchor(TOPLEFT, col2, TOPLEFT, 12, 364)
  dash.statsLegend = makeDashLabel(col2, "DM2StatsMenuDashStatsLegendV4", 9, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  dash.statsLegend:SetAnchor(TOPLEFT, col2, TOPLEFT, 12, 378)
  dash.statsLegend:SetText(formatStatLegendLine())

  dash.statHdrLabel = makeDashLabel(col2, "DM2StatsMenuDashStatHdrL", 10, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  dash.statHdrLabel:SetText("Stat")
  dash.statHdrSheet = makeDashLabel(col2, "DM2StatsMenuDashStatHdrS", 10, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  dash.statHdrSheet:SetText("TOTAL")
  dash.statHdrSheet:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  dash.statHdrTemp = makeDashLabel(col2, "DM2StatsMenuDashStatHdrT", 10, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  dash.statHdrTemp:SetText("FROM BUFFS")
  dash.statHdrTemp:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  dash.statHdrBase = makeDashLabel(col2, "DM2StatsMenuDashStatHdrB", 10, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  dash.statHdrBase:SetText("UNBUFFED")
  dash.statHdrBase:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  dash.statHdrNote = makeDashLabel(col2, "DM2StatsMenuDashStatHdrN", 10, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  dash.statHdrNote:SetText("Pen note")

  for i = 1, DASH_STAT_ROWS do
    local row = WM:CreateControl("DM2StatsMenuDashStatRowV5_" .. i, col2, CT_CONTROL)
    local lab = makeDashLabel(row, "DM2StatsMenuDashStatLabV5_" .. i, 11, THEME.textR, THEME.textG, THEME.textB, 1)
    local sheet = makeDashLabel(row, "DM2StatsMenuDashStatSheetV5_" .. i, 11, THEME.textR, THEME.textG, THEME.textB, 1)
    sheet:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    local temp = makeDashLabel(row, "DM2StatsMenuDashStatTempV5_" .. i, 11, 0.4, 0.95, 0.55, 1)
    temp:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    local base = makeDashLabel(row, "DM2StatsMenuDashStatBaseV5_" .. i, 10, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
    base:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    local note = makeDashLabel(row, "DM2StatsMenuDashStatNoteV5_" .. i, 10, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
    dash.statRows[i] = { row = row, label = lab, sheet = sheet, temp = temp, base = base, note = note }
  end

  dash.critCue = makeDashLabel(col2, "DM2StatsMenuDashCritCueV5", 11, 0.90, 0.82, 0.55, 1)
  dash.penBreakdown = makeDashLabel(col2, "DM2StatsMenuDashPenBrkV5", 10, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  dash.penBreakdown:SetMaxLineCount(2)
  dash.keyBuffTitle = makeDashLabel(col2, "DM2StatsMenuDashKeyBuffTitleV5", 12, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  dash.keyBuffTitle:SetText("KEY SELF-BUFFS")
  dash.keyBuffLine = makeDashLabel(col2, "DM2StatsMenuDashKeyBuffLineV5", 11, THEME.textR, THEME.textG, THEME.textB, 1)
  dash.keyBuffLine:SetMaxLineCount(2)

  -- Champion points — three columns: Combat | Fitness | Craft (fits without scrolling off)
  dash.cpTitle = makeDashLabel(col2, "DM2StatsMenuDashCpTitleV5", 12, THEME.titleR, THEME.titleG, THEME.titleB, 1)
  dash.cpTitle:SetText("SLOTTED CHAMPION POINTS")
  local colKeys = { "combat", "fitness", "craft" }
  local colColors = {
    combat = { 0.91, 0.36, 0.36 },
    fitness = { 0.36, 0.61, 0.84 },
    craft = { 0.44, 0.75, 0.45 },
  }
  for _, key in ipairs(colKeys) do
    local title = makeDashLabel(col2, "DM2StatsMenuDashCpColT_" .. key, 10, colColors[key][1], colColors[key][2], colColors[key][3], 1)
    title:SetText(string.upper(key))
    dash.cpColTitles[key] = title
    for i = 1, 4 do
      local line = makeDashLabel(col2, "DM2StatsMenuDashCpCol_" .. key .. "_" .. i, 10, colColors[key][1], colColors[key][2], colColors[key][3], 1)
      dash.cpCols[key][i] = line
    end
  end

  dash.empty = makeDashLabel(panel, "DM2StatsMenuDashEmptyV3", 16, THEME.mutedR, THEME.mutedG, THEME.mutedB, 1)
  dash.empty:SetAnchor(TOPLEFT, panel, TOPLEFT, CONTENT_PAD, 20)
  dash.empty:SetHidden(true)

  screen.dashboardUI = dash
  return dash
end

local function layoutDashboardUI(screen)
  local dash = screen.dashboardUI
  if not dash or not dash.panel then return end

  local hostW, hostH = layoutContentHost(screen)
  local innerW = hostW - (CONTENT_PAD * 2)
  local colW = math.floor((innerW - DASHBOARD_COL_GAP) / 2)
  local colH = hostH - 16

  for i = 1, 2 do
    local col = dash.cols[i]
    if col and col.control then
      col.control:ClearAnchors()
      col.control:SetAnchor(TOPLEFT, dash.panel, TOPLEFT, CONTENT_PAD + ((i - 1) * (colW + DASHBOARD_COL_GAP)), 8)
      col.control:SetDimensions(colW, colH)
      if col.title then col.title:SetWidth(colW - 24) end
    end
  end

  local textW = colW - 24
  if dash.target then dash.target:SetWidth(textW) end
  if dash.meta then dash.meta:SetWidth(textW) end
  if dash.dummyBadge then dash.dummyBadge:SetWidth(textW) end
  if dash.heroDps then dash.heroDps:SetWidth(textW) end
  if dash.heroSub then dash.heroSub:SetWidth(textW) end
  for _, line in ipairs(dash.rotLines or {}) do line:SetWidth(textW) end
  if dash.sparkTitle then dash.sparkTitle:SetWidth(textW) end
  if dash.skillTitle then dash.skillTitle:SetWidth(textW) end
  if dash.sparkWrap then dash.sparkWrap:SetDimensions(textW, SPARK_BAR_MAX_H + 8) end
  if dash.empty then dash.empty:SetWidth(innerW) end

  for i = 1, 5 do
    local row = dash.topSkills[i]
    if row then
      row.row:SetWidth(textW)
      if row.name then row.name:SetWidth(textW - DASH_TOP_SKILL_ICON - 12) end
      if row.sub then row.sub:SetWidth(textW - DASH_TOP_SKILL_ICON - 12) end
    end
  end

  if dash.frontTitle then dash.frontTitle:SetWidth(textW) end
  if dash.backTitle then dash.backTitle:SetWidth(textW) end
  if dash.gearTitle then dash.gearTitle:SetWidth(textW) end
  for _, line in ipairs(dash.gearLines or {}) do line:SetWidth(textW) end
  if dash.mundusTitle then dash.mundusTitle:SetWidth(textW) end
  if dash.mundusLine then dash.mundusLine:SetWidth(textW) end
  if dash.statsTitle then dash.statsTitle:SetWidth(textW) end
  if dash.statsProv then dash.statsProv:SetWidth(textW) end
  if dash.statsLegend then dash.statsLegend:SetWidth(textW) end

  -- Structured stats: Stat | Sheet (total) | Bonus | Base | pen note
  local labW = math.max(70, math.floor(textW * 0.22))
  local sheetW = math.max(48, math.floor(textW * 0.16))
  local bonusW = math.max(44, math.floor(textW * 0.15))
  local baseW = math.max(44, math.floor(textW * 0.15))
  local noteW = math.max(48, textW - labW - sheetW - bonusW - baseW - 16)
  local sheetX = labW + 4
  local bonusX = sheetX + sheetW + 4
  local baseX = bonusX + bonusW + 4
  local noteX = baseX + baseW + 4
  local hdrY = 388
  local col2c = dash.cols[2] and dash.cols[2].control
  if not col2c then return end
  if dash.statHdrLabel then
    dash.statHdrLabel:ClearAnchors()
    dash.statHdrLabel:SetAnchor(TOPLEFT, col2c, TOPLEFT, 12, hdrY)
    dash.statHdrLabel:SetWidth(labW)
  end
  if dash.statHdrSheet then
    dash.statHdrSheet:ClearAnchors()
    dash.statHdrSheet:SetAnchor(TOPLEFT, col2c, TOPLEFT, 12 + sheetX, hdrY)
    dash.statHdrSheet:SetWidth(sheetW)
  end
  if dash.statHdrTemp then
    dash.statHdrTemp:ClearAnchors()
    dash.statHdrTemp:SetAnchor(TOPLEFT, col2c, TOPLEFT, 12 + bonusX, hdrY)
    dash.statHdrTemp:SetWidth(bonusW)
  end
  if dash.statHdrBase then
    dash.statHdrBase:ClearAnchors()
    dash.statHdrBase:SetAnchor(TOPLEFT, col2c, TOPLEFT, 12 + baseX, hdrY)
    dash.statHdrBase:SetWidth(baseW)
  end
  if dash.statHdrNote then
    dash.statHdrNote:ClearAnchors()
    dash.statHdrNote:SetAnchor(TOPLEFT, col2c, TOPLEFT, 12 + noteX, hdrY)
    dash.statHdrNote:SetWidth(noteW)
  end
  local rowH = 12
  local rowTop = hdrY + 13
  for i = 1, DASH_STAT_ROWS do
    local r = dash.statRows and dash.statRows[i]
    if r and r.row then
      r.row:ClearAnchors()
      r.row:SetAnchor(TOPLEFT, col2c, TOPLEFT, 12, rowTop + (i - 1) * rowH)
      r.row:SetDimensions(textW, rowH)
      r.label:ClearAnchors()
      r.label:SetAnchor(LEFT, r.row, LEFT, 0, 0)
      r.label:SetWidth(labW)
      r.sheet:ClearAnchors()
      r.sheet:SetAnchor(LEFT, r.row, LEFT, sheetX, 0)
      r.sheet:SetWidth(sheetW)
      r.temp:ClearAnchors()
      r.temp:SetAnchor(LEFT, r.row, LEFT, bonusX, 0)
      r.temp:SetWidth(bonusW)
      if r.base then
        r.base:ClearAnchors()
        r.base:SetAnchor(LEFT, r.row, LEFT, baseX, 0)
        r.base:SetWidth(baseW)
      end
      r.note:ClearAnchors()
      r.note:SetAnchor(LEFT, r.row, LEFT, noteX, 0)
      r.note:SetWidth(noteW)
    end
  end
  local afterStatsY = rowTop + DASH_STAT_ROWS * rowH + 2
  if dash.critCue then
    dash.critCue:ClearAnchors()
    dash.critCue:SetAnchor(TOPLEFT, col2c, TOPLEFT, 12, afterStatsY)
    dash.critCue:SetWidth(textW)
  end
  if dash.penBreakdown then
    dash.penBreakdown:ClearAnchors()
    dash.penBreakdown:SetAnchor(TOPLEFT, col2c, TOPLEFT, 12, afterStatsY + 14)
    dash.penBreakdown:SetWidth(textW)
  end
  if dash.keyBuffTitle then
    dash.keyBuffTitle:ClearAnchors()
    dash.keyBuffTitle:SetAnchor(TOPLEFT, col2c, TOPLEFT, 12, afterStatsY + 40)
    dash.keyBuffTitle:SetWidth(textW)
  end
  if dash.keyBuffLine then
    dash.keyBuffLine:ClearAnchors()
    dash.keyBuffLine:SetAnchor(TOPLEFT, col2c, TOPLEFT, 12, afterStatsY + 54)
    dash.keyBuffLine:SetWidth(textW)
  end
  local cpY = afterStatsY + 78
  if dash.cpTitle then
    dash.cpTitle:ClearAnchors()
    dash.cpTitle:SetAnchor(TOPLEFT, col2c, TOPLEFT, 12, cpY)
    dash.cpTitle:SetWidth(textW)
  end
  -- Three columns for Combat / Fitness / Craft
  local cpColW = math.floor((textW - 8) / 3)
  local cpKeys = { "combat", "fitness", "craft" }
  for ci, key in ipairs(cpKeys) do
    local x = 12 + (ci - 1) * (cpColW + 4)
    local title = dash.cpColTitles and dash.cpColTitles[key]
    if title then
      title:ClearAnchors()
      title:SetAnchor(TOPLEFT, col2c, TOPLEFT, x, cpY + 14)
      title:SetWidth(cpColW)
    end
    local lines = dash.cpCols and dash.cpCols[key]
    if lines then
      for i = 1, 4 do
        local line = lines[i]
        if line then
          line:ClearAnchors()
          line:SetAnchor(TOPLEFT, col2c, TOPLEFT, x, cpY + 28 + (i - 1) * 12)
          line:SetWidth(cpColW)
        end
      end
    end
  end
end

local function refreshDashboardUI(screen, session)
  local dash = createDashboardUI(screen)
  if not dash then return end
  layoutDashboardUI(screen)

  if not session then
    if dash.empty then
      dash.empty:SetText("History is empty — complete a parse, then reopen.")
      dash.empty:SetHidden(false)
    end
    for i = 1, 2 do
      if dash.cols[i] and dash.cols[i].control then dash.cols[i].control:SetHidden(true) end
    end
    return
  end

  if dash.empty then dash.empty:SetHidden(true) end
  for i = 1, 2 do
    if dash.cols[i] and dash.cols[i].control then dash.cols[i].control:SetHidden(false) end
  end

  local model = buildDashboardModel(session)
  if not model then return end

  dash.target:SetText(model.target)
  dash.meta:SetText(model.meta)
  dash.dummyBadge:SetText(model.isDummy and "Dummy parse" or "")
  dash.dummyBadge:SetHidden(not model.isDummy)

  dash.heroDps:SetText(model.avgDps .. " DPS")
  dash.heroSub:SetText(string.format(
    "Peak %s  ·  Total %s  ·  Crit %s\n%s",
    model.peakDps, model.totalDamage, model.critPct, model.directDot
  ))

  if dash.rotLines[1] then
    dash.rotLines[1]:SetText(string.format("Weave %s  ·  LA %s", model.weavePct, model.laHits))
  end
  if dash.rotLines[2] then dash.rotLines[2]:SetText(model.weaveDetail) end
  if dash.rotLines[3] then
    local c = model.contrib
    if c and c.parts then
      local bits = {}
      for _, p in ipairs(c.parts) do
        if (p.pct or 0) >= 0.03 then
          bits[#bits + 1] = string.format("%s %s", p.chip or p.label, p.pctTxt)
        end
      end
      dash.rotLines[3]:SetText((#bits > 0) and ("Dmg split  " .. table.concat(bits, " · "))
        or ("Dmg hits  " .. model.events))
    else
      dash.rotLines[3]:SetText("Dmg hits  " .. model.events)
    end
  end

  local colW = 360
  if dash.cols[1] and dash.cols[1].control and type(dash.cols[1].control.GetWidth) == "function" then
    colW = dash.cols[1].control:GetWidth() or colW
  end
  local values = {}
  for _, b in ipairs(model.sparkBuckets or {}) do
    values[#values + 1] = tonumber(b.dmg) or 0
  end
  layoutSparkBars(dash.sparkBars, dash.sparkWrap, values, colW - 24, SPARK_BAR_MAX_H, SPARK_MAX_BARS)

  for i = 1, 5 do
    local row = dash.topSkills[i]
    local sk = model.topSkills[i]
    if row then
      if sk then
        row.row:SetHidden(false)
        local chip = sk.sourceChip or ""
        if chip == "" and sk.source == "Effect" then chip = "E" end
        if chip == "" and sk.source == "Set proc" then chip = "S" end
        local label = sk.name or "?"
        if chip ~= "" then
          label = string.format("[%s] %s", chip, label)
        end
        row.name:SetText(label)
        -- Source type (Skill/Effect) in header gold so it matches other column headers
        local sub = sk.sub or ""
        if sk.source and sk.source ~= "" then
          sub = string.format("|cC0A060%s|r%s", sk.source, string.gsub(sub, "^" .. sk.source, "", 1))
        end
        row.sub:SetText(sub)
        if sk.icon then
          row.icon:SetTexture(sk.icon)
          row.icon:SetHidden(false)
        else
          row.icon:SetHidden(true)
        end
      else
        row.row:SetHidden(true)
      end
    end
  end

  refreshBarIcons(dash.barIcons.front, model.frontBar)
  refreshBarIcons(dash.barIcons.back, model.backBar)

  for i = 1, 4 do
    local line = dash.gearLines[i]
    local setName = model.gearSets[i]
    if line then
      if setName and setName ~= "" then
        line:SetText(setName)
        line:SetHidden(false)
      else
        line:SetHidden(true)
      end
    end
  end
  if #(model.gearSets or {}) == 0 and dash.gearLines[1] then
    dash.gearLines[1]:SetHidden(false)
    dash.gearLines[1]:SetText("(sets unknown — live parse will fill)")
    for i = 2, 4 do
      if dash.gearLines[i] then dash.gearLines[i]:SetHidden(true) end
    end
  end

  -- Mundus (activated stone)
  local mundus = session.mundus or captureActiveMundus()
  if dash.mundusTitle then dash.mundusTitle:SetHidden(false) end
  if dash.mundusLine then
    dash.mundusLine:SetHidden(false)
    dash.mundusLine:SetText(mundus and mundus or "|cAAAAAA(none detected — open character / buffs)|r")
  end

  -- Character stats (fight-end preferred; start available for dual; else live)
  local snapPhase = "live"
  local snap = nil
  if type(session.playerStatsEnd) == "table" then
    snap, snapPhase = session.playerStatsEnd, "end"
  elseif type(session.playerStats) == "table" then
    snap, snapPhase = session.playerStats, "end"
  elseif type(session.playerStatsStart) == "table" then
    snap, snapPhase = session.playerStatsStart, "start"
  else
    snap, snapPhase = capturePlayerStats(), "live"
  end
  if dash.statsTitle then
    dash.statsTitle:SetHidden(false)
    dash.statsTitle:SetText("CHAR STATS")
  end
  if dash.statsProv then
    dash.statsProv:SetHidden(false)
    dash.statsProv:SetText(formatStatProvenance(session, snap, snapPhase))
  end
  if dash.statsLegend then
    dash.statsLegend:SetHidden(false)
    dash.statsLegend:SetText(formatStatLegendLine())
  end
  local statRows = buildStatSnapRows(snap, DASH_STAT_ROWS)
  for i = 1, DASH_STAT_ROWS do
    local r = dash.statRows and dash.statRows[i]
    local d = statRows[i]
    if r then
      if d then
        r.row:SetHidden(false)
        r.label:SetText(d.label or "")
        r.sheet:SetText(d.sheet or "")
        r.temp:SetText(d.temp or "")
        if r.base then r.base:SetText(d.base or "") end
        r.note:SetText(d.note or "")
      else
        r.row:SetHidden(true)
      end
    end
  end
  if dash.critCue then
    dash.critCue:SetHidden(false)
    dash.critCue:SetText(critBalanceCue(snap, session))
  end
  -- Pen contribution one-liner (what builds effective pen)
  if dash.penBreakdown then
    local profile = getActiveContentProfile()
    local coach = getSessionCoach(session)
    if not coach or not coach.waste or not coach.waste.pen then
      coach = buildCoachAnalysis(session, buildBuildSynergy(session), buildParseDiagnosis(session), profile)
      setSessionCoach(session, coach)
    end
    local pen = coach.waste and coach.waste.pen
    if pen then
      local parts = {
        string.format("Personal %s", fmtInt(pen.personal or 0)),
      }
      if (pen.groupEst or 0) > 0 then
        parts[#parts + 1] = string.format("group est. +%s", fmtInt(pen.groupEst))
      end
      parts[#parts + 1] = string.format("effective %s vs %s", fmtInt(pen.effective or 0), fmtInt(pen.resistTarget or 18200))
      dash.penBreakdown:SetText("Pen: " .. table.concat(parts, " · ") .. "  (see Insights §2 for breakdown)")
    else
      dash.penBreakdown:SetText("")
    end
    dash.penBreakdown:SetHidden(false)
  end
  if dash.keyBuffTitle then dash.keyBuffTitle:SetHidden(false) end
  if dash.keyBuffLine then
    local keys = buildKeySelfBuffStrip(session, 6)
    if #keys == 0 then
      dash.keyBuffLine:SetText("|cAAAAAA(no Major Force / Brutality / Sorcery / etc. tracked this fight)|r")
    else
      local bits = {}
      for _, k in ipairs(keys) do
        bits[#bits + 1] = string.format("%s %s", k.label, fmtPct(k.uptime or 0))
      end
      dash.keyBuffLine:SetText(table.concat(bits, "  ·  "))
    end
    dash.keyBuffLine:SetHidden(false)
  end

  -- Slotted CP — three columns Combat | Fitness | Craft
  local cps = collectSlottedChampionSkills(12)
  local buckets = {
    combat = {},
    fitness = {},
    craft = {},
  }
  for _, cp in ipairs(cps) do
    local key = cp.constellation or "craft"
    if not buckets[key] then key = "craft" end
    local list = buckets[key]
    list[#list + 1] = cp
  end
  if dash.cpTitle then
    dash.cpTitle:SetHidden(false)
    dash.cpTitle:SetText((#cps > 0)
      and string.format("SLOTTED CHAMPION POINTS  (%d)", #cps)
      or "SLOTTED CHAMPION POINTS")
  end
  local titles = { combat = "COMBAT", fitness = "FITNESS", craft = "CRAFT" }
  for key, list in pairs(buckets) do
    local title = dash.cpColTitles and dash.cpColTitles[key]
    if title then
      title:SetHidden(false)
      title:SetText(string.format("%s (%d)", titles[key] or key, #list))
    end
    local lines = dash.cpCols and dash.cpCols[key]
    if lines then
      for i = 1, 4 do
        local line = lines[i]
        local cp = list[i]
        if line then
          if cp then
            line:SetHidden(false)
            line:SetText(displayName(cp.name or "?", 18))
          else
            line:SetText("")
            line:SetHidden(i > 1 or #list > 0)
            if i == 1 and #list == 0 then
              line:SetHidden(false)
              line:SetText("|c666666—|r")
            end
          end
        end
      end
    end
  end
end

local function refreshActiveContentTab(screen, tabIndex, session)
  showContentTab(screen, tabIndex)
  if tabIndex == TAB.DASHBOARD then
    refreshDashboardUI(screen, session)
  elseif tabIndex == TAB.DAMAGE then
    refreshDamageUI(screen, session)
  elseif tabIndex == TAB.WEAVE then
    refreshWeaveUI(screen, session)
  elseif tabIndex == TAB.BUFFS then
    refreshBuffsUI(screen, session)
  elseif tabIndex == TAB.GEAR then
    refreshGearUI(screen, session)
  elseif tabIndex == TAB.PROCS then
    refreshProcsUI(screen, session)
  elseif tabIndex == TAB.ROTATION then
    refreshRotationUI(screen, session)
  elseif tabIndex == TAB.INSIGHTS_DPS or tabIndex == TAB.INSIGHTS then
    refreshInsightsUI(screen, session, "dps")
  elseif tabIndex == TAB.INSIGHTS_BUILD then
    refreshInsightsUI(screen, session, "build")
  elseif tabIndex == TAB.HISTORY then
    refreshHistoryUI(screen)
  else
    refreshOverviewUI(screen, session)
  end
end

---------------------------------------------------------------------
-- List / entry helpers
---------------------------------------------------------------------
local function makeEntry(label, subLabel, tabIndex)
  if ZO_GamepadEntryData == nil then return nil end
  local ok, entry = pcall(function() return ZO_GamepadEntryData:New(tostring(label or "")) end)
  if not ok or not entry then return nil end
  if subLabel and subLabel ~= "" then
    if type(entry.AddSubLabel) == "function" then entry:AddSubLabel(tostring(subLabel))
    elseif type(entry.SetSubLabel) == "function" then entry:SetSubLabel(tostring(subLabel)) end
  end
  entry.dm2Tab = tabIndex
  return entry
end

local function refreshNavList(screen)
  local list = screen.navList
  if not list then return 0 end
  list:Clear()
  local added = 0
  for _, entry in ipairs(NAV_ENTRIES) do
    local e = makeEntry(entry.label, entry.sub, entry.tab)
    if e then
      local ok = pcall(function() list:AddEntry("ZO_GamepadMenuEntryTemplate", e) end)
      if ok then added = added + 1 end
    end
  end
  if type(list.Commit) == "function" then pcall(function() list:Commit() end) end
  if type(list.RefreshVisible) == "function" then pcall(function() list:RefreshVisible() end) end
  if added == 0 and not listPopulateWarned then
    listPopulateWarned = true
    d("|cFFAA00DM2 Stats Menu|r: nav list failed to populate.")
  end
  return added
end

local function activateNavList(screen)
  if not screen or not screen.navList then return end
  screen:SetCurrentList(screen.navList)
  layoutNavList(screen)
  if type(screen.navList.RefreshVisible) == "function" then pcall(function() screen.navList:RefreshVisible() end) end
  if type(screen.navList.Activate) == "function" then pcall(function() screen.navList:Activate() end) end
end

---------------------------------------------------------------------
-- Gamepad screen
---------------------------------------------------------------------
if type(ZO_Gamepad_ParametricList_Screen) == "table" and type(ZO_Gamepad_ParametricList_Screen.Subclass) == "function" then
  DM2StatsMenuShell_Gamepad = ZO_Gamepad_ParametricList_Screen:Subclass()
else
  DM2StatsMenuShell_Gamepad = {}
end

function DM2StatsMenuShell_Gamepad:New(control)
  local obj = ZO_Object.New(self)
  obj:Initialize(control)
  return obj
end

local function getHeaderCreateMode()
  if ZO_GAMEPAD_HEADER_TABBAR_DONT_CREATE ~= nil then return ZO_GAMEPAD_HEADER_TABBAR_DONT_CREATE end
  if ZO_GAMEPAD_HEADER_TABBAR_CREATE ~= nil then return ZO_GAMEPAD_HEADER_TABBAR_CREATE end
  return true
end

function DM2StatsMenuShell_Gamepad:Initialize(control)
  self.control = control
  self.currentTab = TAB.OVERVIEW
  self._suppressNavCallback = false
  local ACTIVATE_ON_SHOW = true
  ZO_Gamepad_ParametricList_Screen.Initialize(self, control, getHeaderCreateMode(), ACTIVATE_ON_SHOW, sceneObject)
  -- MUST stay false: true steals L2/R2 for nav-list jump top/bottom and breaks fight history.
  self:SetListsUseTriggerKeybinds(false)
end

function DM2StatsMenuShell_Gamepad:OnDeferredInitialize()
  -- CRITICAL: do NOT create all content panels here.
  -- Creating 9 heavy UIs in one frame exceeds console CPU budget (1000ms) and freezes UI.
  -- Panels are lazy-created on first visit in refreshActiveContentTab.
  if self._deferredInitDone then return end
  self._deferredInitDone = true
  if not self.navList then
    self:InitializeLists()
  end
  -- Re-assert: list must not own L2/R2 (history walk).
  if type(self.SetListsUseTriggerKeybinds) == "function" then
    self:SetListsUseTriggerKeybinds(false)
  end
  ensureContentHost(self)
  self:ApplyWideLayout()
end

function DM2StatsMenuShell_Gamepad:ApplyWideLayout()
  local control = self.control
  if not control then return end
  local rootW = GuiRoot and GuiRoot:GetWidth() or 1920
  local rootH = GuiRoot and GuiRoot:GetHeight() or 1080
  control:ClearAnchors()
  control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 0, 0)
  control:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, 0, 0)

  local container = self.container
  if not container and type(control.GetNamedChild) == "function" then
    container = control:GetNamedChild("Container")
  end
  if container then
    self.container = container
    container:ClearAnchors()
    container:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
    container:SetDimensions(rootW, rootH)
    container:SetHidden(false)
  end
  if self.header and type(self.header.ClearAnchors) == "function" then
    self.header:ClearAnchors()
    self.header:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
    if type(self.header.SetWidth) == "function" then self.header:SetWidth(rootW) end
  end
  applyDualPaneLayout(self)
  if self.currentTab == TAB.DASHBOARD then
    layoutDashboardUI(self)
  end
end

function DM2StatsMenuShell_Gamepad:RefreshHeader()
  if not self.header then return end
  local section = sectionLabelForTab(self.currentTab)
  local exp = getActiveExperiment()
  local expBit = "A: experiment on Insights"
  if exp then
    local n = type(exp.runs) == "table" and #exp.runs or 0
    local need = tonumber(exp.targetRuns) or 3
    expBit = exp.completed
      and string.format("EXP DONE %d/%d", n, need)
      or string.format("EXP ON %d/%d", n, need)
  end
  local subtitle = "v3.17.16  |  L2/R2 fights  |  " .. expBit .. "  |  "
    .. (headerNote ~= "" and headerNote or section)
  local headerData = {
    titleText = R.displayName or "DM2 Parse & Fight Stats",
    subtitleText = subtitle,
  }
  pcall(function()
    ZO_GamepadGenericHeader_Refresh(self.header, headerData, true)
    ZO_GamepadGenericHeader_Activate(self.header)
  end)
end

function DM2StatsMenuShell_Gamepad:SyncNavListSelection()
  local list = self.navList
  if not list or type(list.SetSelectedIndex) ~= "function" then return end
  self._suppressNavCallback = true
  pcall(function() list:SetSelectedIndex(self.currentTab or TAB.OVERVIEW) end)
  self._suppressNavCallback = false
end

function DM2StatsMenuShell_Gamepad:SelectTab(tabIndex, fromNav)
  tabIndex = tonumber(tabIndex) or TAB.OVERVIEW
  if tabIndex < TAB.OVERVIEW then tabIndex = TAB.OVERVIEW end
  if tabIndex > TAB_MAX then tabIndex = TAB_MAX end
  if self.currentTab == tabIndex and fromNav and self._contentReady then
    -- same tab re-select from stick: only ensure visible, skip full rebuild
    return
  end
  self.currentTab = tabIndex
  if self._refreshing then return end
  if not fromNav then
    self:SyncNavListSelection()
  end
  -- Tab switch: only refresh active content (lazy create that panel).
  self:_RefreshContentLight()
  -- Experiment keybind visibility depends on Insights: DPS tab
  if type(KEYBIND_STRIP) == "table" and type(KEYBIND_STRIP.UpdateKeybindButtonGroup) == "function" and keybindGroup then
    pcall(function() KEYBIND_STRIP:UpdateKeybindButtonGroup(keybindGroup) end)
  end
end

function DM2StatsMenuShell_Gamepad:InitializeLists()
  if self.navList then return end
  local screen = self
  local function setupList(list)
    list:AddDataTemplate("ZO_GamepadMenuEntryTemplate", ZO_SharedGamepadEntry_OnSetup, ZO_GamepadMenuEntryTemplateParametricListFunction)
    list:SetNoItemText("No sections")
    list:SetReselectBehavior(ZO_PARAMETRIC_SCROLL_LIST_RESELECT_BEHAVIOR.RESELECT_OLD_INDEX)
    if type(list.SetOnSelectedDataChangedCallback) == "function" then
      list:SetOnSelectedDataChangedCallback(function()
        if screen._suppressNavCallback then return end
        if screen._refreshing then return end
        -- Prefer entry.dm2Tab (authoritative). List index only as fallback when
        -- TAB ids match NAV order (they must — see TAB definition comment).
        local idx = nil
        if type(list.GetTargetData) == "function" then
          local data = list:GetTargetData()
          if data and data.dm2Tab then idx = tonumber(data.dm2Tab) end
        end
        if not idx and type(list.GetSelectedIndex) == "function" then
          idx = tonumber(list:GetSelectedIndex())
        end
        if idx and idx >= TAB.OVERVIEW and idx <= TAB_MAX then
          screen:SelectTab(idx, true)
        end
      end)
    end
  end
  self.navList = self:AddList("Navigation", function(list) setupList(list) end)
  self:SetCurrentList(self.navList)
end

-- Light refresh: active tab only (used for nav stick / history cycle).
function DM2StatsMenuShell_Gamepad:_RefreshContentLight()
  if self._refreshing then return end
  self._refreshing = true
  local ok, err = pcall(function()
    if not self._deferredInitDone then self:OnDeferredInitialize() end
    local session = resolveSession()
    self:RefreshHeader()
    refreshActiveContentTab(self, self.currentTab or TAB.OVERVIEW, session)
    self._contentReady = true
  end)
  self._refreshing = false
  if not ok then
    d("|cFFAA00DM2 Stats Menu|r: content refresh failed: " .. tostring(err))
  end
end

-- Full refresh: nav list + active tab (open scene / history walk).
function DM2StatsMenuShell_Gamepad:RefreshContent()
  if self._refreshing then return end
  self._refreshing = true
  local ok, err = pcall(function()
    if not self._deferredInitDone then self:OnDeferredInitialize() end
    if not self._navPopulated then
      refreshNavList(self)
      self._navPopulated = true
    end
    activateNavList(self)
    self:SyncNavListSelection()
    local session = resolveSession()
    self:RefreshHeader()
    refreshActiveContentTab(self, self.currentTab or TAB.OVERVIEW, session)
    self._contentReady = true
  end)
  self._refreshing = false
  if not ok then
    d("|cFFAA00DM2 Stats Menu|r: content load failed: " .. tostring(err))
  end
end

function DM2StatsMenuShell_Gamepad:CycleHistory(delta)
  delta = tonumber(delta) or 0
  if delta == 0 then return end
  local count = historyCount()
  if count <= 0 then
    -- Quiet: spamming when empty is noise
    return
  end
  local nextOffset = clampHistoryOffset((historyOffset or 0) + delta, count)
  if nextOffset == historyOffset then
    -- Edge of list — silent (R2 on #1 used to spam "already on latest fight")
    return
  end
  historyOffset = nextOffset
  M._rotTimelinePage = 1 -- reset skill-timeline page when walking history
  self:_RefreshContentLight()
  M.RefreshKeybindStrip()
end

-- Called from main after a successful history save (keep menu on newest parse)
function M.OnFightSaved()
  historyOffset = 0
  M._rotTimelinePage = 1
  if screenObject and type(SCENE_MANAGER) == "table"
      and SCENE_MANAGER:IsShowing(SCENE_NAME) then
    pcall(function()
      if type(screenObject._RefreshContentLight) == "function" then
        screenObject:_RefreshContentLight()
      elseif type(screenObject.RefreshContent) == "function" then
        screenObject:RefreshContent()
      end
      M.RefreshKeybindStrip()
    end)
  end
end

function DM2StatsMenuShell_Gamepad:OnBackButtonPressed()
  M.Hide()
end

function DM2StatsMenuShell_Gamepad:OnShowing()
  if ZO_Gamepad_ParametricList_Screen.OnShowing then
    pcall(function() ZO_Gamepad_ParametricList_Screen.OnShowing(self) end)
  end
  -- Lightweight setup only on the showing frame — heavy work next frame.
  self.currentTab = TAB.OVERVIEW
  historyOffset = 0
  self._navPopulated = false
  self._contentReady = false
  self._showGen = (self._showGen or 0) + 1
  local gen = self._showGen

  pcall(function() self:OnDeferredInitialize() end)
  if type(self.SetListsUseTriggerKeybinds) == "function" then
    pcall(function() self:SetListsUseTriggerKeybinds(false) end)
  end
  pcall(function() self:ApplyWideLayout() end)
  M.RefreshKeybindStrip()

  -- Spread work: next frame = nav + Overview only (lazy create one panel).
  zo_callLater(function()
    if not screenObject or screenObject._showGen ~= gen then return end
    if type(SCENE_MANAGER) ~= "table" or not SCENE_MANAGER:IsShowing(SCENE_NAME) then return end
    pcall(function()
      screenObject:ApplyWideLayout()
      screenObject:RefreshContent()
    end)
  end, 1)

  -- Layout settle only — do NOT rebuild content a third time.
  zo_callLater(function()
    if not screenObject or screenObject._showGen ~= gen then return end
    if type(SCENE_MANAGER) ~= "table" or not SCENE_MANAGER:IsShowing(SCENE_NAME) then return end
    pcall(function() screenObject:ApplyWideLayout() end)
  end, 100)
end

function DM2StatsMenuShell_Gamepad:OnHiding()
  M.ClearKeybindStrip()
  if self.header and type(ZO_GamepadGenericHeader_Deactivate) == "function" then
    pcall(function() ZO_GamepadGenericHeader_Deactivate(self.header) end)
  end
end

---------------------------------------------------------------------
-- Scene / menu entry / keybinds
---------------------------------------------------------------------
local function getGamepadControl()
  if type(GetControl) == "function" then
    local ok, control = pcall(GetControl, "DM2StatsMenuShellGamepadTopLevel")
    if ok and control then return control end
  end
  if DM2StatsMenuShellGamepadTopLevel then return DM2StatsMenuShellGamepadTopLevel end
  return nil
end

local function addMainMenuEntry()
  if menuEntryAdded or not MAIN_MENU_GAMEPAD then return end
  if ZO_GamepadEntryData == nil then return end

  local function makeEntry(id)
    local entry = ZO_GamepadEntryData:New(R.displayName or "DM2 Parse & Fight Stats",
      "EsoUI/Art/TreeIcons/Gamepad/gp_tutorial_idexIcon_combat.dds")
    entry:SetIconTintOnSelection(true)
    entry:SetIconDisabledTintOnSelection(true)
    entry.data = { scene = SCENE_NAME }
    entry.id = id
    return entry
  end

  local journalEntry, characterEntry = nil, nil
  if type(ZO_MENU_ENTRIES) == "table" and type(ZO_MENU_MAIN_ENTRIES) == "table" then
    for _, v in ipairs(ZO_MENU_ENTRIES) do
      if v.id == ZO_MENU_MAIN_ENTRIES.JOURNAL then
        journalEntry = v
      end
      -- Character sheet root (Battle Scrolls-style secondary home)
      if ZO_MENU_MAIN_ENTRIES.CHARACTER and v.id == ZO_MENU_MAIN_ENTRIES.CHARACTER then
        characterEntry = v
      end
      if ZO_MENU_MAIN_ENTRIES.CHAMPION and v.id == ZO_MENU_MAIN_ENTRIES.CHAMPION then
        -- keep looking; character preferred
      end
    end
  end

  -- Primary: Journal (existing)
  if journalEntry and journalEntry.subMenu then
    table.insert(journalEntry.subMenu, makeEntry(MENU_ENTRY_ID))
  elseif type(ZO_MENU_ENTRIES) == "table" then
    table.insert(ZO_MENU_ENTRIES, makeEntry(MENU_ENTRY_ID))
  end

  -- Stretch: also under Character sheet when the client exposes a submenu
  if characterEntry and type(characterEntry.subMenu) == "table" then
    local already = false
    for _, e in ipairs(characterEntry.subMenu) do
      if e and e.id == (MENU_ENTRY_ID + 1) then already = true break end
    end
    if not already then
      table.insert(characterEntry.subMenu, makeEntry(MENU_ENTRY_ID + 1))
    end
  end

  -- GAMEPAD_STATS category list (character attributes / sets panel) when available
  if type(GAMEPAD_STATS) == "table" and type(GAMEPAD_STATS.AddCategory) == "function" then
    pcall(function()
      GAMEPAD_STATS:AddCategory(R.displayName or "Parse & Fight", function()
        M.Show()
      end)
    end)
  elseif type(GAMEPAD_STATS) == "table" and type(GAMEPAD_STATS.categoryList) == "table" then
    -- Best-effort: some clients expose categoryList:AddEntry
    pcall(function()
      if ZO_GamepadEntryData and GAMEPAD_STATS.categoryList.AddEntry then
        local e = ZO_GamepadEntryData:New(R.displayName or "Parse & Fight")
        e.callback = function() M.Show() end
        GAMEPAD_STATS.categoryList:AddEntry("ZO_GamepadMenuEntryTemplate", e)
      end
    end)
  end

  MAIN_MENU_GAMEPAD:RefreshLists()
  MAIN_MENU_GAMEPAD:UpdateEntryEnabledStates()
  menuEntryAdded = true
end

local function buildScene()
  if sceneObject then return true end
  if sceneBuildFailed then return false end
  if type(ZO_Gamepad_ParametricList_Screen) ~= "table" then
    sceneBuildFailed = true
    d("|cFFAA00DM2 Stats Menu|r: gamepad parametric screen unavailable.")
    return false
  end
  local control = getGamepadControl()
  if not control then
    sceneBuildFailed = true
    d("|cFFAA00DM2 Stats Menu|r: shell control missing (MenuShell.xml not loaded?).")
    return false
  end
  control:SetHidden(true)

  fragmentObject = ZO_FadeSceneFragment:New(control)
  fragmentObject:RegisterCallback("StateChange", function(_, newState)
    if not screenObject then return end
    if newState == SCENE_FRAGMENT_SHOWING then
      screenObject:OnShowing()
    elseif newState == SCENE_FRAGMENT_HIDING then
      screenObject:OnHiding()
    end
  end)

  sceneObject = ZO_Scene:New(SCENE_NAME, SCENE_MANAGER)
  sceneObject:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
  sceneObject:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD)
  if type(GAMEPAD_NAV_QUADRANT_1_3_BACKGROUND_FRAGMENT) ~= "nil" then
    sceneObject:AddFragment(GAMEPAD_NAV_QUADRANT_1_3_BACKGROUND_FRAGMENT)
  else
    sceneObject:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
  end
  if type(GAMEPAD_NAV_QUADRANT_2_3_BACKGROUND_FRAGMENT) ~= "nil" then
    sceneObject:AddFragment(GAMEPAD_NAV_QUADRANT_2_3_BACKGROUND_FRAGMENT)
  end
  if type(KEYBIND_STRIP_GAMEPAD_FRAGMENT) ~= "nil" then
    sceneObject:AddFragment(KEYBIND_STRIP_GAMEPAD_FRAGMENT)
  end
  sceneObject:AddFragment(GAMEPAD_GENERIC_FOOTER_FRAGMENT)
  sceneObject:AddFragment(GAMEPAD_MENU_SOUND_FRAGMENT)
  sceneObject:AddFragment(FRAME_EMOTE_FRAGMENT_SOCIAL)
  sceneObject:AddFragment(fragmentObject)

  sceneObject:RegisterCallback("StateChange", function(_, newState)
    if newState == SCENE_SHOWING then
      M.RefreshKeybindStrip()
    elseif newState == SCENE_HIDING or newState == SCENE_HIDDEN then
      M.ClearKeybindStrip()
    end
  end)

  if not screenObject then
    screenObject = DM2StatsMenuShell_Gamepad:New(control)
  end
  return true
end

local function sceneIsShowing()
  return type(SCENE_MANAGER) == "table" and SCENE_MANAGER:IsShowing(SCENE_NAME)
end

local function ensureKeybindGroup()
  if keybindGroup or type(KEYBIND_STRIP) ~= "table" then return end
  local function historyEnabled()
    return sceneIsShowing() and historyCount() > 1
  end
  local function experimentVisible()
    if not sceneIsShowing() then return false end
    if getActiveExperiment() then return true end
    return screenObject and screenObject.currentTab == TAB.INSIGHTS_DPS
  end
  local function rotationPageVisible()
    return sceneIsShowing() and screenObject and screenObject.currentTab == TAB.ROTATION
      and (tonumber(M._rotTimelinePages) or 1) > 1
  end
  keybindGroup = {
    alignment = KEYBIND_STRIP_ALIGN_CENTER,
    {
      name = "Older Fight",
      keybind = "UI_SHORTCUT_LEFT_TRIGGER",
      order = 100,
      callback = function()
        if screenObject and type(screenObject.CycleHistory) == "function" then
          screenObject:CycleHistory(1)
        end
      end,
      visible = sceneIsShowing,
      enabled = historyEnabled,
    },
    {
      name = "Newer Fight",
      keybind = "UI_SHORTCUT_RIGHT_TRIGGER",
      order = 110,
      callback = function()
        if screenObject and type(screenObject.CycleHistory) == "function" then
          screenObject:CycleHistory(-1)
        end
      end,
      visible = sceneIsShowing,
      enabled = historyEnabled,
    },
    {
      -- Phase 2.5.3: Start / Abandon / Clear controlled experiment
      -- PRIMARY (A/Cross) — more reliable on gamepad than Secondary/Y for many users
      name = experimentKeybindName,
      keybind = "UI_SHORTCUT_PRIMARY",
      order = 150,
      callback = function()
        local session = historyAt(historyOffset)
        local result = toggleExperimentFromUi(session)
        -- Refresh session pointer after toggle (may still be same table)
        session = historyAt(historyOffset)
        if screenObject then
          if type(screenObject.RefreshHeader) == "function" then
            pcall(function() screenObject:RefreshHeader() end)
          end
          refreshActiveContentTab(screenObject, screenObject.currentTab or TAB.OVERVIEW, session)
        end
        if type(KEYBIND_STRIP) == "table" and type(KEYBIND_STRIP.UpdateKeybindButtonGroup) == "function" and keybindGroup then
          pcall(function() KEYBIND_STRIP:UpdateKeybindButtonGroup(keybindGroup) end)
        end
        -- Chat cue so state is obvious even if footer glyph is easy to miss
        if result == "started" then
          d("|c66FF88DM2|r Experiment |c66FF88ON|r — next matching dummy parses count toward the test.")
        elseif result == "cleared" then
          d("|cFFCC66DM2|r Experiment |cFF6666OFF|r — cleared.")
        end
      end,
      visible = experimentVisible,
      enabled = experimentKeybindEnabled,
    },
    {
      -- Rotation skill timeline pages (Square on PS / Y on Xbox) — only if fight overflows panel
      name = function()
        local p = tonumber(M._rotTimelinePage) or 1
        local pages = tonumber(M._rotTimelinePages) or 1
        return string.format("Next page %d/%d", p, pages)
      end,
      keybind = "UI_SHORTCUT_SECONDARY",
      order = 160,
      callback = function()
        local pages = math.max(1, tonumber(M._rotTimelinePages) or 1)
        M._rotTimelinePage = ((tonumber(M._rotTimelinePage) or 1) % pages) + 1
        local session = historyAt(historyOffset)
        if screenObject then
          refreshActiveContentTab(screenObject, TAB.ROTATION, session)
        end
        if type(KEYBIND_STRIP) == "table" and type(KEYBIND_STRIP.UpdateKeybindButtonGroup) == "function" and keybindGroup then
          pcall(function() KEYBIND_STRIP:UpdateKeybindButtonGroup(keybindGroup) end)
        end
      end,
      visible = rotationPageVisible,
      enabled = rotationPageVisible,
    },
    {
      name = "Back",
      keybind = "UI_SHORTCUT_NEGATIVE",
      order = 200,
      gamepadName = (type(GetString) == "function" and SI_GAMEPAD_BACK_OPTION ~= nil) and GetString(SI_GAMEPAD_BACK_OPTION) or "Back",
      callback = function() M.Hide() end,
      visible = sceneIsShowing,
    },
  }
end

function M.RefreshKeybindStrip()
  if type(KEYBIND_STRIP) ~= "table" then return end
  ensureKeybindGroup()
  if not keybindGroup then return end
  pcall(function() KEYBIND_STRIP:AddKeybindButtonGroup(keybindGroup) end)
  if type(KEYBIND_STRIP.UpdateKeybindButtonGroup) == "function" then
    pcall(function() KEYBIND_STRIP:UpdateKeybindButtonGroup(keybindGroup) end)
  end
end

function M.ClearKeybindStrip()
  if keybindGroup and type(KEYBIND_STRIP) == "table" then
    pcall(function() KEYBIND_STRIP:RemoveKeybindButtonGroup(keybindGroup) end)
  end
end

function M.Hide()
  M.ClearKeybindStrip()
  if type(SCENE_MANAGER) ~= "table" then return end
  if SCENE_MANAGER:IsShowing(SCENE_NAME) then
    SCENE_MANAGER:Hide(SCENE_NAME)
    return
  end
  if type(SCENE_MANAGER.HideCurrentScene) == "function" then
    pcall(function() SCENE_MANAGER:HideCurrentScene() end)
  end
end

function M.IsShowing()
  return sceneIsShowing()
end

function M.Show()
  if not isGamepadPreferred() then
    d("|cFFAA00DM2 Stats Menu|r: gamepad/console mode required.")
    return
  end
  if not buildScene() then return end
  historyOffset = 0
  if type(SCENE_MANAGER) == "table" and type(SCENE_MANAGER.Show) == "function" then
    SCENE_MANAGER:Show(SCENE_NAME)
  end
end

function M.Initialize()
  zo_callLater(function()
    if sceneObject or buildScene() then
      addMainMenuEntry()
    end
  end, 2500)
end

function R:ShowMenu()
  M.Show()
end

function R:HideMenu()
  M.Hide()
end

end -- installMenuUI
installMenuUI()
