---------------------------------------------------------------------
-- DM2_ParseFightStats_RaidHud.lua — left-side raid essentials strip
-- Own file so the main chunk stays under Lua 5.1's 200-local limit.
-- Polls every 400ms. Never touches EVENT_COMBAT_EVENT.
---------------------------------------------------------------------
DM2Stats = DM2Stats or {}
local R = DM2Stats
local EM = EVENT_MANAGER
local WM = WINDOW_MANAGER

local UPDATE_MS = 400
local PEN_CAP = 18200
-- CP160 sheet: 219 crit rating = 1% chance. 100% is the real ceiling.
local CRIT_PER_PCT = 219
local MAJOR_BREACH = 5948
local MINOR_BREACH = 2974
local CRUSHER = 2108
local ALKOSH = 3010

local function isHousing()
  if type(GetCurrentZoneHouseId) == "function" then
    local ok, hid = pcall(GetCurrentZoneHouseId)
    if ok and tonumber(hid) and tonumber(hid) > 0 then return true end
  end
  if type(IsOwnerOfCurrentHouse) == "function" then
    local ok, res = pcall(IsOwnerOfCurrentHouse)
    if ok and res == true then return true end
  end
  return false
end

local function isDungeonOrTrial()
  if type(IsUnitInDungeon) == "function" then
    local ok, v = pcall(IsUnitInDungeon, "player")
    if ok and v then return true end
  end
  if type(GetCurrentZoneDungeonDifficulty) == "function" then
    local ok, d = pcall(GetCurrentZoneDungeonDifficulty)
    if ok and tonumber(d) and tonumber(d) > 0 then return true end
  end
  if type(GetMapContentType) == "function" and type(MAP_CONTENT_DUNGEON) == "number" then
    local ok, t = pcall(GetMapContentType)
    if ok and t == MAP_CONTENT_DUNGEON then return true end
  end
  return false
end

local function wanted()
  local SV = R.SV
  if not SV or not SV.settings or SV.settings.enable == false then return false end
  if type(DM2StatsMenuShell) == "table" and type(DM2StatsMenuShell.IsShowing) == "function" then
    local ok, showing = pcall(DM2StatsMenuShell.IsShowing)
    if ok and showing then return false end
  end
  if SV.settings.showRaidStrip ~= false and isDungeonOrTrial() then return true end
  if SV.settings.showRaidStripOnDummy ~= false then
    if isHousing() then return true end
    local sess = R.session
    if type(sess) == "table" and sess.started and sess.isDummy then return true end
  end
  return false
end

local function ensure()
  R.ui = R.ui or {}
  if R.ui.raidStrip then return R.ui.raidStrip end
  local win = WM:CreateTopLevelWindow("DM2StatsRaidStrip")
  -- Name column fits BERSERK/COURAGE/HEROISM; status is right-justified so ON/MIN/CAP never collide.
  win:SetDimensions(128, 308)
  win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 18, 160)
  win:SetHidden(true)
  win:SetDrawLayer(DL_OVERLAY)
  win:SetDrawTier(DT_HIGH)
  win:SetDrawLevel(400000)
  win:SetMouseEnabled(false)
  win:SetClampedToScreen(true)
  local bg = WM:CreateControl("DM2StatsRaidStripBg", win, CT_BACKDROP)
  bg:SetAnchorFill(win)
  bg:SetCenterColor(0.04, 0.05, 0.07, 0.62)
  bg:SetEdgeColor(0.25, 0.32, 0.40, 0.45)
  bg:SetInsets(2, 2, -2, -2)
  local title = WM:CreateControl("DM2StatsRaidStripTitle", win, CT_LABEL)
  title:SetFont("EsoUI/Common/Fonts/univers67.otf|14|soft-shadow-thick")
  title:SetColor(0.95, 0.82, 0.40, 1)
  title:SetAnchor(TOPLEFT, win, TOPLEFT, 6, 4)
  title:SetDimensions(116, 16)
  title:SetText("RAID")
  local defs = {
    { label = "FORCE",   kind = "player", major = "major force",         minor = "minor force" },
    { label = "SLAYER",  kind = "player", major = "major slayer",        minor = "minor slayer" },
    { label = "BERSERK", kind = "player", major = "major berserk",       minor = "minor berserk" },
    { label = "COURAGE", kind = "player", major = "major courage",       minor = "minor courage" },
    { label = "HEROISM", kind = "player", major = "major heroism",       minor = "minor heroism" },
    { label = "BREACH",  kind = "target", major = "major breach",        minor = "minor breach" },
    { label = "CRUSHER", kind = "target", major = "crusher",             minor = nil },
    { label = "BRITTLE", kind = "target", major = "major brittle",       minor = "minor brittle" },
    { label = "VULN",    kind = "target", major = "major vulnerability", minor = "minor vulnerability" },
    { label = "PEN",     kind = "pen" },
    { label = "CRIT",    kind = "crit" },
  }
  local rows = {}
  for i = 1, #defs do
    local y = 22 + (i - 1) * 26
    local pip = WM:CreateControl("DM2StatsRaidStripPip" .. i, win, CT_BACKDROP)
    pip:SetDimensions(8, 8)
    pip:SetAnchor(TOPLEFT, win, TOPLEFT, 6, y + 6)
    pip:SetCenterColor(0.5, 0.5, 0.5, 1)
    pip:SetEdgeColor(0, 0, 0, 0)
    local name = WM:CreateControl("DM2StatsRaidStripName" .. i, win, CT_LABEL)
    name:SetFont("EsoUI/Common/Fonts/univers67.otf|13|soft-shadow-thick")
    name:SetAnchor(TOPLEFT, win, TOPLEFT, 18, y)
    name:SetDimensions(68, 16)
    name:SetMaxLineCount(1)
    name:SetText(defs[i].label)
    local val = WM:CreateControl("DM2StatsRaidStripVal" .. i, win, CT_LABEL)
    val:SetFont("EsoUI/Common/Fonts/univers67.otf|13|soft-shadow-thick")
    val:SetAnchor(TOPRIGHT, win, TOPRIGHT, -6, y)
    val:SetDimensions(38, 16)
    val:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    val:SetMaxLineCount(1)
    val:SetText("—")
    rows[i] = { def = defs[i], pip = pip, name = name, val = val }
  end
  win.rows = rows
  R.ui.raidStrip = win
  return win
end

local function scanUnit(unitTag, names)
  if type(GetNumBuffs) ~= "function" or type(GetUnitBuffInfo) ~= "function" then return end
  if type(DoesUnitExist) == "function" then
    local okE, exists = pcall(DoesUnitExist, unitTag)
    if okE and exists == false then return end
  end
  local okN, n = pcall(GetNumBuffs, unitTag)
  n = okN and (tonumber(n) or 0) or 0
  if n <= 0 then return end
  for i = 1, n do
    local ok, buffName = pcall(GetUnitBuffInfo, unitTag, i)
    if ok and type(buffName) == "string" and buffName ~= "" then
      names[string.lower(buffName)] = true
    end
  end
end

local function hasName(names, needle)
  if not needle or needle == "" then return false end
  if names[needle] then return true end
  for n in pairs(names) do
    if string.find(n, needle, 1, true) then return true end
  end
  return false
end

local function readPersonalPen()
  local function read(const)
    if type(const) ~= "number" or type(GetPlayerStat) ~= "function" then return 0 end
    local ok, v = pcall(GetPlayerStat, const)
    return (ok and tonumber(v)) or 0
  end
  return math.max(read(_G.STAT_PHYSICAL_PENETRATION), read(_G.STAT_SPELL_PENETRATION))
end

local function readCritChancePct()
  local function read(const)
    if type(const) ~= "number" or type(GetPlayerStat) ~= "function" then return 0 end
    local ok, v = pcall(GetPlayerStat, const)
    return (ok and tonumber(v)) or 0
  end
  local rating = math.max(read(_G.STAT_CRITICAL_STRIKE), read(_G.STAT_SPELL_CRITICAL))
  if rating <= 0 then return 0 end
  -- Same conversion as the stats page (rating / 219). No added 10%, and no
  -- Major Prophecy on top — a live GetPlayerStat already includes those.
  local pct = math.floor(rating / CRIT_PER_PCT + 0.5)
  if pct > 100 then pct = 100 end
  return pct
end

local function paint(row, mode, text)
  local pr, pg, pb = 0.55, 0.55, 0.55
  if mode == "cap" or mode == "on" then pr, pg, pb = 0.40, 0.90, 0.48
  elseif mode == "low" then pr, pg, pb = 0.95, 0.78, 0.28
  elseif mode == "off" then pr, pg, pb = 0.88, 0.32, 0.28
  end
  if row.pip then row.pip:SetCenterColor(pr, pg, pb, 1) end
  if row.name then row.name:SetColor(pr, pg, pb, 1) end
  if row.val then
    row.val:SetColor(pr, pg, pb, 1)
    row.val:SetText(text or "—")
  end
end

local function tick()
  if not wanted() then
    if R.ui and R.ui.raidStrip then R.ui.raidStrip:SetHidden(true) end
    return
  end
  local win = ensure()
  if not win then return end
  win:SetHidden(false)
  local mine, tgt = {}, {}
  pcall(scanUnit, "player", mine)
  pcall(scanUnit, "reticleover", tgt)
  pcall(scanUnit, "boss1", tgt)
  pcall(scanUnit, "boss2", tgt)
  local sess = R.session
  if type(sess) == "table" and type(sess.targetDebuffs) == "table" then
    for _, d in pairs(sess.targetDebuffs) do
      if type(d) == "table" and d.name and d.activeStartMs then
        tgt[string.lower(tostring(d.name))] = true
      end
    end
  end
  local majB = hasName(tgt, "major breach")
  local minB = hasName(tgt, "minor breach")
  local crush = hasName(tgt, "crusher")
  local alk = hasName(tgt, "alkosh")
  local critPct = readCritChancePct()
  local penPct = math.floor(math.min(1,
    (readPersonalPen()
      + (majB and MAJOR_BREACH or 0)
      + (minB and MINOR_BREACH or 0)
      + (crush and CRUSHER or 0)
      + (alk and ALKOSH or 0)) / PEN_CAP) * 100 + 0.5)
  local rows = win.rows or {}
  for i = 1, #rows do
    local row = rows[i]
    local def = row and row.def
    if def then
      if def.kind == "pen" then
        if penPct >= 100 then paint(row, "cap", "CAP")
        elseif penPct >= 80 then paint(row, "low", tostring(penPct) .. "%")
        else paint(row, "off", tostring(penPct) .. "%") end
      elseif def.kind == "crit" then
        local mode = "off"
        if critPct >= 50 then mode = "on"
        elseif critPct >= 35 then mode = "low" end
        paint(row, mode, tostring(critPct) .. "%")
      else
        local bag = (def.kind == "target") and tgt or mine
        if def.major and hasName(bag, def.major) then paint(row, "on", "ON")
        elseif def.minor and hasName(bag, def.minor) then paint(row, "low", "MIN")
        else paint(row, "off", "OFF") end
      end
    end
  end
end

function R.StartRaidStrip()
  local name = (R.name or "DM2_ParseFightStats") .. "_RaidStrip"
  EM:UnregisterForUpdate(name)
  EM:RegisterForUpdate(name, UPDATE_MS, function()
    pcall(tick)
  end)
end
