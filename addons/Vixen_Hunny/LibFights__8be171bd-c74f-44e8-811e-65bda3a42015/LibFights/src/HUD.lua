--[[
    LibFights - HUD
    Live fight rundown window: status, timer, DPS/HPS/DTPS/crit tiles, actions line, boss health
    with time-to-kill, top abilities and a fight log. Built in Lua (no XML) and added to the HUD
    scenes, so it works with keyboard and gamepad UI on PC and console.

    Showing the HUD never starts logging by itself. It only reads fights and listens to the
    library's callbacks (registered while the HUD is shown).

      +----------------------------------------------+
      | o LibFights                  LIVE | LOGGING  |
      | #12 Target Dummy  Zone                0:42.3 |
      | [ DPS ][ HPS ][ DTPS ][ Crit  ]              |
      | [ Dmg ][ Heal][ Taken][MaxHit ]              |
      | APM 52  Weave 87%  Bars 62% / 38%  Swaps 14  |
      | Boss 63%  TTK 0:31  Proj. DPS 88k  [=====  ] |
      | TOP DAMAGE                                   |
      | [icon] Ability ............... 120k  31%     |
      | FIGHT LOG                                    |
      | 12:03:44 Fight #12 started                   |
      +----------------------------------------------+
]]

local LF = LibFights
local Util, Const = LF.Util, LF.Const
local HUD = {}
LF.HUD = HUD

local WM = WINDOW_MANAGER
local EM = EVENT_MANAGER
local fmt = string.format
local floor, max = math.floor, math.max
local N, P = Util.FormatNumber, Util.FormatPct

local TICK_NS = "LibFights_HUD"
local ABILITY_ROWS, LOG_LINES, LOG_CAP = 5, 8, 100

local function S() return LF.GetSettings() end

local C = {
    bg      = { 0.04, 0.05, 0.07, 0.85 },
    edge    = { 0.35, 0.55, 0.85, 0.70 },
    tile    = { 1, 1, 1, 0.05 },
    rowBg   = { 1, 1, 1, 0.04 },
    barDmg  = { 0.85, 0.35, 0.25, 0.55 },
    barHeal = { 0.30, 0.80, 0.40, 0.55 },
    boss    = { 0.85, 0.20, 0.20, 0.80 },
    bossBg  = { 1, 1, 1, 0.08 },
    caption = { 0.62, 0.66, 0.72 },
    live    = { 0.36, 0.92, 0.48 },
    wait    = { 0.40, 0.75, 1.00 },
    last    = { 1.00, 0.78, 0.30 },
    idle    = { 0.55, 0.55, 0.55 },
}

HUD.LOG_COLOR = {
    info = "C8CCD2", good = "5BEA7A", warn = "FFC74D", bad = "FF6B6B", proc = "80C0FF", hit = "FFD700",
}

local ui = nil

-- ===========================================================================
-- Fight log (ring buffer, newest last). Other add-ons may write to it too.
-- ===========================================================================
local log = {}

-- kind: "info" "good" "warn" "bad" "proc" "hit" (sets the color)
function HUD.Log(kind, text, ...)
    text = tostring(text)
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, text, ...)
        if ok then text = formatted end
    end
    log[#log + 1] = {
        clock = (type(GetTimeString) == "function" and GetTimeString()) or "",
        color = HUD.LOG_COLOR[kind] or HUD.LOG_COLOR.info,
        text = text,
    }
    if #log > LOG_CAP then table.remove(log, 1) end
    HUD.RefreshLog()
end

function HUD.GetLog(n)
    local out = {}
    for i = max(1, #log - (n or #log) + 1), #log do out[#out + 1] = log[i] end
    return out
end

function HUD.ClearLog()
    log = {}
    HUD.RefreshLog()
end

-- ===========================================================================
-- Build
-- ===========================================================================
local SCALE = 1
local function px(n) return floor(n * SCALE + 0.5) end

local function Place(ctrl, parent, x, y, w, h)
    ctrl:ClearAnchors()
    ctrl:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    if w and h then ctrl:SetDimensions(w, h) end
end

local function Label(name, parent, font, color, align)
    local l = WM:CreateControl(name, parent, CT_LABEL)
    l:SetFont(font)
    color = color or { 1, 1, 1 }
    l:SetColor(color[1], color[2], color[3], 1)
    l:SetHorizontalAlignment(align or TEXT_ALIGN_LEFT)
    l:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    if l.SetMaxLineCount then l:SetMaxLineCount(1) end
    if l.SetWrapMode and TEXT_WRAP_MODE_ELLIPSIS then l:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS) end
    l:SetText("")
    return l
end

local function Box(name, parent, color, edge)
    local b = WM:CreateControl(name, parent, CT_BACKDROP)
    b:SetCenterColor(color[1], color[2], color[3], color[4] or 1)
    if edge then
        b:SetEdgeColor(edge[1], edge[2], edge[3], edge[4] or 1)
        pcall(b.SetEdgeTexture, b, "", 1, 1, 1)
    else
        b:SetEdgeColor(0, 0, 0, 0)
    end
    return b
end

local function Tint(ctrl, c) ctrl:SetCenterColor(c[1], c[2], c[3], c[4] or 1) end

local TILES = {
    { key = "dps", cap = "DPS" }, { key = "hps", cap = "HPS" }, { key = "dtps", cap = "DTPS" }, { key = "crit", cap = "Crit" },
    { key = "damage", cap = "Damage" }, { key = "healing", cap = "Healing" }, { key = "taken", cap = "Taken" }, { key = "maxHit", cap = "Max hit" },
}

function HUD.Create()
    if HUD.window then return HUD.window end
    local gamepad = LF.IsGamepad()
    SCALE = gamepad and 1.25 or 1
    local F = {
        title = gamepad and "ZoFontGamepadBold22" or "ZoFontGameBold",
        normal = gamepad and "ZoFontGamepad22" or "ZoFontGame",
        small = gamepad and "ZoFontGamepad18" or "ZoFontGameSmall",
        value = gamepad and "ZoFontGamepadBold27" or "ZoFontWinH3",
    }
    local WIDTH, PAD, GAP = px(380), px(8), px(4)
    local innerW = WIDTH - 2 * PAD
    ui = { tiles = {}, rows = {}, logs = {} }

    local win = WM:CreateTopLevelWindow("LibFightsHUD")
    win:SetClampedToScreen(true)
    win:SetMouseEnabled(not LF.isConsole)
    win:SetMovable(not LF.isConsole and not S().hudLocked)
    win:ClearAnchors()
    win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, S().hudX or 60, S().hudY or 320)
    win:SetHandler("OnMoveStop", function(self)
        S().hudX, S().hudY = self:GetLeft(), self:GetTop()
    end)

    Box("$(parent)BG", win, C.bg, C.edge):SetAnchorFill()
    local y = PAD

    -- header
    local hH = px(22)
    ui.dot = Box("$(parent)Dot", win, C.idle)
    Place(ui.dot, win, PAD, y + floor((hH - px(10)) / 2), px(10), px(10))
    ui.title = Label("$(parent)Title", win, F.title)
    Place(ui.title, win, PAD + px(16), y, floor(innerW * 0.45), hH)
    ui.title:SetText("LibFights")
    ui.status = Label("$(parent)Status", win, F.small, C.idle, TEXT_ALIGN_RIGHT)
    Place(ui.status, win, PAD + floor(innerW * 0.45), y, innerW - floor(innerW * 0.45), hH)
    y = y + hH + px(2)

    -- fight line
    local fH = px(20)
    ui.fight = Label("$(parent)Fight", win, F.normal)
    Place(ui.fight, win, PAD, y, innerW - px(80), fH)
    ui.timer = Label("$(parent)Timer", win, F.normal, nil, TEXT_ALIGN_RIGHT)
    Place(ui.timer, win, PAD + innerW - px(80), y, px(80), fH)
    y = y + fH + px(6)

    -- tiles (2 rows x 4)
    local tileW, tileH = floor((innerW - 3 * GAP) / 4), px(42)
    for i, t in ipairs(TILES) do
        local col, row = (i - 1) % 4, floor((i - 1) / 4)
        local tx, ty = PAD + col * (tileW + GAP), y + row * (tileH + GAP)
        Place(Box("$(parent)Tile" .. i, win, C.tile), win, tx, ty, tileW, tileH)
        local v = Label("$(parent)TileV" .. i, win, F.value, nil, TEXT_ALIGN_CENTER)
        Place(v, win, tx, ty + px(2), tileW, px(24))
        local c = Label("$(parent)TileC" .. i, win, F.small, C.caption, TEXT_ALIGN_CENTER)
        Place(c, win, tx, ty + px(25), tileW, px(15))
        c:SetText(t.cap)
        ui.tiles[t.key] = v
    end
    y = y + 2 * tileH + GAP + px(6)

    -- info + boss
    local lH = px(18)
    ui.info = Label("$(parent)Info", win, F.small, C.caption)
    Place(ui.info, win, PAD, y, innerW, lH)
    y = y + lH
    ui.boss = Label("$(parent)Boss", win, F.small)
    Place(ui.boss, win, PAD, y, innerW, lH)
    y = y + lH
    ui.bossBg = Box("$(parent)BossBg", win, C.bossBg)
    Place(ui.bossBg, win, PAD, y + px(1), innerW, px(4))
    ui.bossFill = Box("$(parent)BossFill", win, C.boss)
    Place(ui.bossFill, win, PAD, y + px(1), innerW, px(4))
    ui.bossW = innerW
    y = y + px(10)

    -- top abilities
    ui.abilHeader = Label("$(parent)AbilHdr", win, F.small, C.caption)
    Place(ui.abilHeader, win, PAD, y, innerW, lH)
    ui.abilHeader:SetText("TOP DAMAGE")
    y = y + lH
    local rowH = px(20)
    ui.rowW = innerW
    for i = 1, ABILITY_ROWS do
        local r = {}
        r.bg = Box("$(parent)RowBg" .. i, win, C.rowBg)
        Place(r.bg, win, PAD, y, innerW, rowH)
        r.fill = Box("$(parent)RowFill" .. i, win, C.barDmg)
        Place(r.fill, win, PAD, y, innerW, rowH)
        r.icon = WM:CreateControl("$(parent)RowIcon" .. i, win, CT_TEXTURE)
        Place(r.icon, win, PAD + px(2), y + px(2), rowH - px(4), rowH - px(4))
        r.name = Label("$(parent)RowName" .. i, win, F.small)
        Place(r.name, win, PAD + rowH + px(2), y, innerW - rowH - px(110), rowH)
        r.value = Label("$(parent)RowVal" .. i, win, F.small, nil, TEXT_ALIGN_RIGHT)
        Place(r.value, win, PAD + innerW - px(108), y, px(104), rowH)
        ui.rows[i] = r
        y = y + rowH + px(2)
    end
    y = y + px(6)

    -- fight log
    local logHdr = Label("$(parent)LogHdr", win, F.small, C.caption)
    Place(logHdr, win, PAD, y, innerW, lH)
    logHdr:SetText("FIGHT LOG")
    y = y + lH
    for i = 1, LOG_LINES do
        local l = Label("$(parent)Log" .. i, win, F.small)
        Place(l, win, PAD, y, innerW, px(16))
        ui.logs[i] = l
        y = y + px(16)
    end
    win:SetDimensions(WIDTH, y + PAD)

    HUD.window, HUD.label = win, ui.fight -- HUD.label kept for older callers
    if ZO_HUDFadeSceneFragment then
        HUD.fragment = ZO_HUDFadeSceneFragment:New(win)
    elseif ZO_SimpleSceneFragment then
        HUD.fragment = ZO_SimpleSceneFragment:New(win)
    end
    win:SetHidden(true)
    return win
end

-- ===========================================================================
-- Refresh
-- ===========================================================================
local function HideRow(r)
    r.bg:SetHidden(true); r.fill:SetHidden(true); r.icon:SetHidden(true)
    r.name:SetText(""); r.value:SetText("")
end

local function ClearFight()
    ui.fight:SetText(LF.Logger.IsLogging() and "|c9AA0A8Logging. Waiting for combat.|r" or "|c9AA0A8No fight yet. Start_Logging() and fight something.|r")
    ui.timer:SetText("")
    for _, l in pairs(ui.tiles) do l:SetText("-") end
    ui.info:SetText("")
    ui.boss:SetText("")
    ui.bossBg:SetHidden(true)
    ui.bossFill:SetHidden(true)
    for _, r in ipairs(ui.rows) do HideRow(r) end
end

local function SetStatus(text, color)
    ui.status:SetText(text)
    ui.status:SetColor(color[1], color[2], color[3], 1)
    Tint(ui.dot, color)
end

local function RefreshBoss(f, s, live)
    local bh = f.bossHealth and f.bossHealth.boss1
    if bh and (bh.maxHealth or 0) > 0 then
        local frac = Util.Clamp((bh.current or 0) / bh.maxHealth, 0, 1)
        local parts = { fmt("|cFF8080%s|r %s", bh.name or "Boss", P(frac, 0)) }
        if live and LF.Models then
            local ttk = LF.Models.GetTTK("boss1")
            if ttk then parts[#parts + 1] = "TTK " .. Util.FormatDuration(ttk * 1000) end
            local o = LF.Models.PredictFightOutcome(f)
            if o and o.predictedFinalDPS then parts[#parts + 1] = "Proj. DPS " .. N(o.predictedFinalDPS) end
        end
        ui.boss:SetText(table.concat(parts, "   "))
        ui.bossBg:SetHidden(false)
        ui.bossFill:SetHidden(frac <= 0)
        ui.bossFill:SetWidth(max(1, floor(ui.bossW * frac)))
        return
    end
    ui.bossBg:SetHidden(true)
    ui.bossFill:SetHidden(true)
    local t = f:GetTargets(1)[1]
    if t and t.damage > 0 then
        ui.boss:SetText(fmt("Top target: %s%s  %s (%s)  %s DPS", t.name ~= "" and t.name or "?",
            t.killed and " |c9AA0A8[killed]|r" or "", N(t.damage), P(t.pct, 0), N(t.dps)))
    else
        ui.boss:SetText(fmt("Targets: %d", s.numTargets or 0))
    end
end

local function RefreshAbilities(f, s)
    local healer = (s.healing or 0) > (s.damage or 0)
    ui.abilHeader:SetText(healer and "TOP HEALING" or "TOP DAMAGE")
    local rows = f:GetAbilityBreakdown(healer and "healOut" or "damageOut", "total", ABILITY_ROWS)
    for i, r in ipairs(ui.rows) do
        local a = rows[i]
        if a and a.total > 0 then
            r.bg:SetHidden(false)
            r.fill:SetHidden(false)
            Tint(r.fill, healer and C.barHeal or C.barDmg)
            r.fill:SetWidth(max(1, floor(ui.rowW * Util.Clamp(a.pct or 0, 0, 1))))
            if a.icon and a.icon ~= "" then r.icon:SetTexture(a.icon); r.icon:SetHidden(false) else r.icon:SetHidden(true) end
            r.name:SetText(fmt("%s  |c9AA0A8%s crit|r", a.name or ("#" .. tostring(a.id)), P(a.critRate, 0)))
            r.value:SetText(fmt("%s  |c9AA0A8%s|r", N(a.total), P(a.pct, 0)))
        else
            HideRow(r)
        end
    end
end

function HUD.RefreshLog()
    if not ui then return end
    local entries = HUD.GetLog(#ui.logs)
    local offset = #ui.logs - #entries -- newest entry on the bottom line
    for i, l in ipairs(ui.logs) do
        local e = entries[i - offset]
        l:SetText(e and fmt("|c7A808A%s|r |c%s%s|r", e.clock, e.color, e.text) or "")
    end
end

function HUD.Update()
    if not ui then return end
    local current = LF.Logger.GetCurrentFight()
    local f = current or LF.Logger.GetLastFinishedFight()
    local live = current ~= nil

    if live then SetStatus("LIVE  |  LOGGING", C.live)
    elseif LF.Logger.IsLogging() then SetStatus("LOGGING  |  waiting", C.wait)
    elseif f then SetStatus("LAST FIGHT  |  not logging", C.last)
    else SetStatus("IDLE  |  not logging", C.idle) end

    if not f then
        ClearFight()
        HUD.RefreshLog()
        return
    end
    local s = (not live and f.summary) or f:GetSummary()
    local zone = (s.zone and s.zone ~= "") and ("  |c9AA0A8" .. s.zone .. "|r") or ""
    local ended = (not live and f.endReason) and ("  |c9AA0A8(" .. f.endReason .. ")|r") or ""
    ui.fight:SetText(fmt("|cFFD700#%d|r %s%s%s", s.id or 0, s.title or "?", zone, ended))
    ui.timer:SetText(Util.FormatDuration(s.durationMs))

    local T = ui.tiles
    T.dps:SetText(N(s.dps)); T.hps:SetText(N(s.hps)); T.dtps:SetText(N(s.dtps)); T.crit:SetText(P(s.critRate, 0))
    T.damage:SetText(N(s.damage)); T.healing:SetText(N(s.healing)); T.taken:SetText(N(s.damageTaken)); T.maxHit:SetText(N(s.maxHit))

    ui.info:SetText(fmt("APM %.0f   Weave %s   Bars %s / %s   Swaps %d   Procs %d   Deaths %d",
        s.apm or 0, P(s.weaveRatio, 0), P(s.frontBarPct, 0), P(s.backBarPct, 0),
        s.barSwaps or 0, s.procActivations or 0, s.deaths or 0))
    RefreshBoss(f, s, live)
    RefreshAbilities(f, s)
    HUD.RefreshLog()
end
HUD.Refresh = HUD.Update

-- ===========================================================================
-- Library callbacks -> fight log (registered only while the HUD is shown)
-- ===========================================================================
local track = { liveFightId = nil, seenProcs = {}, topHit = 0, loggedTop = 0, pendingTop = nil, lastTopLogMs = 0 }
HUD._track = track

local function FlushTopHit()
    local p = track.pendingTop
    if not p then return end
    track.pendingTop = nil
    if p.hit < track.loggedTop * 1.10 then return end -- only when it clearly beats the last logged one
    track.loggedTop = p.hit
    track.lastTopLogMs = GetGameTimeMilliseconds()
    HUD.Log("hit", "New top hit %s%s  %s", N(p.hit), p.crit and " (crit)" or "", LF.Abilities.GetName(p.abilityId))
end

local function NoteDiscarded()
    if track.liveFightId then
        HUD.Log("warn", "Fight #%d discarded (too short or no damage)", track.liveFightId)
        track.liveFightId = nil
    end
end

local function Tick()
    local current = LF.Logger.GetCurrentFight()
    if track.pendingTop and GetGameTimeMilliseconds() - track.lastTopLogMs >= 2000 then FlushTopHit() end
    -- the logger drops short/empty fights without firing FIGHT_ENDED
    if track.liveFightId and (not current or current.id ~= track.liveFightId) then NoteDiscarded() end
    if not current then EM:UnregisterForUpdate(TICK_NS) end
    HUD.Update()
end

local function StartTicking()
    EM:UnregisterForUpdate(TICK_NS)
    EM:RegisterForUpdate(TICK_NS, max(100, S().hudUpdateMs or 500), Tick)
end

local cb = {}
function cb.FightStarted(f)
    if track.liveFightId and track.liveFightId ~= f.id then NoteDiscarded() end
    track.liveFightId = f.id
    track.seenProcs, track.topHit, track.loggedTop, track.pendingTop = {}, 0, 0, nil
    track.lastTopLogMs = GetGameTimeMilliseconds()
    HUD.Log("good", "Fight #%d started", f.id)
    StartTicking()
    HUD.Update()
end

function cb.FightEnded(f, reason)
    FlushTopHit()
    track.liveFightId = nil
    local s = f.summary or f:GetSummary()
    HUD.Log("good", "Fight #%d ended (%s)  %s  %s DPS  %s HPS", f.id, tostring(reason), Util.FormatDuration(s.durationMs), N(s.dps), N(s.hps))
    local top = f:GetAbilityBreakdown("damageOut", "total", 1)[1]
    if top and top.total > 0 then HUD.Log("info", "Top ability %s  %s (%s)", top.name, N(top.total), P(top.pct, 0)) end
    HUD.Update()
end

function cb.LoggingStarted()
    HUD.Log("good", "Logging started")
    HUD.Update()
end

function cb.LoggingStopped()
    NoteDiscarded()
    HUD.Log("info", "Logging stopped")
    EM:UnregisterForUpdate(TICK_NS)
    HUD.Update()
end

function cb.Death(f, d)
    if d.unitTag == "player" then
        local last
        for i = #(d.recap or {}), 1, -1 do
            local r = d.recap[i]
            if r.hit and r.hit > 0 and Const.GetResultCategory(r.result) == "damage" then last = r break end
        end
        if last then
            HUD.Log("bad", "You died: %s %s from %s", last.abilityName or "?", N(last.hit), (last.source and last.source ~= "") and last.source or "?")
        else
            HUD.Log("bad", "You died")
        end
    else
        HUD.Log("good", "%s died", (d.name and d.name ~= "") and d.name or tostring(d.unitTag))
    end
end

function cb.Proc(f, p)
    if track.seenProcs[p.id] or p.kind ~= "set" then return end -- set procs only; candidates are noisy
    track.seenProcs[p.id] = true
    HUD.Log("proc", "Proc %s  <%s>", p.name, p.setName or "?")
end

local DIR_OUT, CRIT = LF.Fight.DIR.OUT, Const.CRIT_RESULTS
function cb.Combat(f, direction, category, result, abilityId, hit)
    if direction ~= DIR_OUT or category ~= "damage" or not hit or hit <= track.topHit then return end
    track.topHit = hit
    track.pendingTop = { hit = hit, abilityId = abilityId, crit = CRIT[result] or false }
end

local CALLBACKS = {
    { "FIGHT_STARTED", "FightStarted" }, { "FIGHT_ENDED", "FightEnded" },
    { "LOGGING_STARTED", "LoggingStarted" }, { "LOGGING_STOPPED", "LoggingStopped" },
    { "DEATH", "Death" }, { "PROC", "Proc" }, { "COMBAT_EVENT", "Combat" },
}

local function SetListening(on)
    if (HUD.listening or false) == on then return end
    for _, c in ipairs(CALLBACKS) do
        if on then LF.RegisterCallback(LF.EVENTS[c[1]], cb[c[2]]) else LF.UnregisterCallback(LF.EVENTS[c[1]], cb[c[2]]) end
    end
    HUD.listening = on
    if on then
        -- shown mid-fight: pick up the running fight
        local current = LF.Logger.GetCurrentFight()
        if current then track.liveFightId = current.id; StartTicking() end
    else
        EM:UnregisterForUpdate(TICK_NS)
        track.liveFightId = nil
    end
end

-- ===========================================================================
-- Show / hide / lock
-- ===========================================================================
function HUD.IsShown()
    return HUD.visible == true
end

function HUD.Show()
    HUD.Create()
    if HUD.fragment and not HUD.fragmentAdded then
        if HUD_SCENE then HUD_SCENE:AddFragment(HUD.fragment) end
        if HUD_UI_SCENE then HUD_UI_SCENE:AddFragment(HUD.fragment) end
        HUD.fragmentAdded = true
    end
    if not HUD.fragment then HUD.window:SetHidden(false) end
    HUD.visible = true
    SetListening(true)
    HUD.Update()
end

function HUD.Hide()
    SetListening(false)
    if HUD.fragment and HUD.fragmentAdded then
        if HUD_SCENE then HUD_SCENE:RemoveFragment(HUD.fragment) end
        if HUD_UI_SCENE then HUD_UI_SCENE:RemoveFragment(HUD.fragment) end
        HUD.fragmentAdded = false
    end
    if HUD.window then HUD.window:SetHidden(true) end
    HUD.visible = false
end

function HUD.SetShown(shown)
    S().showHUD = shown and true or false
    if shown then HUD.Show() else HUD.Hide() end
end

function HUD.SetLocked(locked)
    S().hudLocked = locked and true or false
    if HUD.window then HUD.window:SetMovable(not LF.isConsole and not locked) end
end

function HUD.ResetPosition()
    S().hudX, S().hudY = nil, nil
    if HUD.window then
        HUD.window:ClearAnchors()
        HUD.window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 60, 320)
    end
end

function HUD.Init()
    if S().showHUD then HUD.Show() end
end
