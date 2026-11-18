-- CombatMascot v0.6.1 (release: 7 reactions + heal by registered skill series; DIAG off; double-mascot guard Sweep stays)
-- v0.5.2: skills are registered in the settings ("register last used skill as heal"). A registered skill is matched by its
-- skill SERIES (skill type / line / index: morphs and ranks of one skill share it) when GetSpecificSkillAbilityKeysByAbilityId
-- exists on the PS5, otherwise by its ability id only. A registered skill plays the heal reaction INSTEAD of the skill reaction.
-- heal  = only YOUR OWN direct heal (ACTION_RESULT_HEAL, source = player); crit heal, HoT and heals from others are not connected.
-- guard = block (BLOCKED_DAMAGE) / dodge (DODGED) / shield absorb (DAMAGE_SHIELDED) on the player: ONE shared reaction.
-- heal is lowest priority: it only plays while nothing else is playing (never interrupts, never replaces).
-- Independent addon (no dependency on PlayerMascotHealth; LibAddonMenu-2.0 is OPTIONAL). Event driven: no OnUpdate,
-- no polling, textures are loaded once and reused. A new event is always received: during the motion phase
-- (ANIM_MS) a lower-priority reaction is dropped, an equal / higher one replaces the playing one at once; during
-- the last-frame hold anything replaces it. No queue. Every play has a token: a stale end-timer / stale OnStop is
-- ignored. DIAG = true shows event-time counters under the mascot (set DIAG = false for the release build).
-- v0.4.0: the waiting picture (CM_IDLE.dds, 4x2 = 8 frames) loops while no reaction plays; a reaction hides it and
-- it comes back when the reaction ends. If CM_IDLE.dds cannot be built, reactions still work (nothing is shown idle).

local ADDON    = "CombatMascot"
local PATH     = "CombatMascot/"
local VERSION  = "0.6.1"
local SV_NAME, SV_VERSION = "CombatMascot_SV", 1

------------------------------------------------------------------
-- Constants
------------------------------------------------------------------
local FPS       = 8                       -- 4 frames -> 0.5 s of animation
local ANIM_MS   = 500                     -- frames / FPS
local HOLD_MS   = 800                     -- last frame is held this long, then the reaction ends
local TOTAL_MS  = ANIM_MS + HOLD_MS       -- 1.3 s per reaction

local DIAG      = false                   -- diagnostic counters on screen (temporary; false in the release build)
local STOP_TOL  = 150                     -- OnStop "finished" is trusted only if >= ANIM_MS - STOP_TOL ms passed since this play started

-- reaction priority: a LOWER one never interrupts a HIGHER one during the motion phase
local PRI = { heal = 2, attack = 1, skill = 2, hit = 2, guard = 2, kill = 3, ult = 4 }

local SIZE_MIN, SIZE_MAX, SIZE_STEP = 128, 768, 8   -- displayed height in UI px (cell is square)

-- every sheet: 512x512 = 2 x 2 cells of 256x256, 4 frames, left->right, top->bottom
local SHEETS = {
    attack = { file = "CM_ATTACK.dds", cols = 2, rows = 2 },
    skill  = { file = "CM_SKILL.dds",  cols = 2, rows = 2 },
    ult    = { file = "CM_ULT.dds",    cols = 2, rows = 2 },
    hit    = { file = "CM_HIT.dds",    cols = 2, rows = 2 },
    kill   = { file = "CM_KILL.dds",   cols = 2, rows = 2 },
    heal   = { file = "CM_HEAL.dds",   cols = 2, rows = 2 },
    guard  = { file = "CM_GUARD.dds",  cols = 2, rows = 2 },
}
local ORDER = { "attack", "skill", "ult", "hit", "kill", "heal", "guard" }

-- waiting picture: 1024x512 = 4 x 2 cells of 256x256, 8 frames, looped
local IDLE = { file = "CM_IDLE.dds", cols = 4, rows = 2, fps = 5 }   -- 8 frames / 5 fps = 1.6 s per loop
local IDLE_MS = math.floor(IDLE.cols * IDLE.rows * 1000 / IDLE.fps)  -- the loop is a one-shot restarted by a timer (no LOOP constants)

------------------------------------------------------------------
-- Saved settings (own data only)
------------------------------------------------------------------
local function ScreenSize()
    local sw, sh = 1920, 1080
    pcall(function()
        local w, h = GuiRoot:GetWidth(), GuiRoot:GetHeight()
        if type(w) == "number" and w > 0 then sw = w end
        if type(h) == "number" and h > 0 then sh = h end
    end)
    return sw, sh
end

local DEFAULTS
do
    local sw, sh = ScreenSize()
    DEFAULTS = {
        enabled = true,
        size    = 256,
        x       = math.max(0, math.floor(sw - 256 - 120)),   -- right side (PlayerMascotHealth sits at the left)
        y       = math.floor(sh * 0.35),
    }
end

local sv = {}                   -- saved variables (sanitized); a plain table copy of DEFAULTS if saving is unavailable

local function Num(v, lo, hi, fallback)
    if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then return fallback end
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function Sanitize()
    if type(sv) ~= "table" then sv = {} end
    if type(sv.enabled) ~= "boolean" then sv.enabled = DEFAULTS.enabled end
    sv.x    = Num(sv.x, 0, 8000, DEFAULTS.x)
    sv.y    = Num(sv.y, 0, 8000, DEFAULTS.y)
    sv.size = Num(sv.size, SIZE_MIN, SIZE_MAX, DEFAULTS.size)
    if type(sv.heal) ~= "table" then sv.heal = {} end       -- registered heal skill series ("type:line:index" = true)
    if type(sv.healId) ~= "table" then sv.healId = {} end   -- registered heal ability ids (fallback / exact match)
end

------------------------------------------------------------------
-- Display: one top-level window; every reaction texture fills it (common position / size)
------------------------------------------------------------------
local tlw                       -- top-level window
local E = {}                    -- E[key] = { ctrl, tl, cols, rows, at }
local idle                      -- waiting picture: { ctrl, tl } (nil if it could not be built)
local idleTok = 0               -- invalidates the idle restart timer
local hudFragment               -- shows the window on the HUD only (nil if it could not be created)
local preview = false           -- runtime only, never saved: keep visible in menus
local cur                       -- key of the reaction playing now (nil = none)
local token = 0                 -- play counter: a stale end-timer / stale OnStop is ignored
local animUntil = 0             -- game time (ms) until which the playing reaction is in its protected motion phase
local lastStart = 0             -- game time (ms) of the last accepted play (diagnostic only)
local diagLabel                 -- diagnostic text (only when DIAG)

local D = {
    recv = { attack = 0, skill = 0, ult = 0, hit = 0, kill = 0, heal = 0, guard = 0 },
    play = { attack = 0, skill = 0, ult = 0, hit = 0, kill = 0, heal = 0, guard = 0 },
    evHeal = "-", lastHeal = "-", healZero = 0, lastGuard = "-",
    drop = 0, oldlock = 0, staleT = 0, stopAll = 0, stopIgn = 0, hold = 0,
    err = 0, lastErr = "-", hsId = "-", hsKey = "-", hsMatch = 0, cp = "-", dtLast = 0, dtMax = 0,
    built = 0, evSlot = "-", evHit = "-", font = 0, idleB = 0, idleN = 0, idleVis = "-", rVis = "-",
}

-- pcall that does NOT hide a failure: it is counted and the last message is kept for the diagnostic screen
local function Try(f, ...)
    local ok, err = pcall(f, ...)
    if not ok then
        D.err = D.err + 1
        local s = tostring(err)
        s = s:gsub("%s+", " ")
        D.lastErr = s:sub(1, 48)
    end
    return ok
end

-- states of every texture control, as digits: i a s u h k (idle, attack, skill, ult, hit, kill); 1 = yes, 0 = no
local function CtrlFlag(c, method)
    if not c then return "-" end
    local ok, v = pcall(c[method], c)
    if not ok then return "?" end
    if method == "IsHidden" then v = not v end
    return v and "1" or "0"
end
local function Flags(method)
    local out = { CtrlFlag(idle and idle.ctrl, method) }
    for _, k in ipairs({ "attack", "skill", "ult", "hit", "kill", "heal", "guard" }) do
        out[#out + 1] = CtrlFlag(E[k] and E[k].ctrl, method)
    end
    return table.concat(out)
end
local function ShownStates() return Flags("IsHidden") end
local function LoadedStates() return Flags("IsTextureLoaded") end

local function RegCount()
    local n = 0
    if type(sv.heal) == "table" then for _ in pairs(sv.heal) do n = n + 1 end end
    if type(sv.healId) == "table" then for _ in pairs(sv.healId) do n = n + 1 end end
    return n
end

-- skill series of an ability id: "type:line:index" (morphs / ranks of one skill share it); nil when the API is missing
local lastSkill = { id = nil, key = nil }
local function SkillKey(abilityId)
    if GetSpecificSkillAbilityKeysByAbilityId == nil or type(abilityId) ~= "number" or abilityId <= 0 then return nil end
    local ok, t, l, i = pcall(GetSpecificSkillAbilityKeysByAbilityId, abilityId)
    if ok and type(t) == "number" and t > 0 and type(l) == "number" and type(i) == "number" then
        return string.format("%d:%d:%d", t, l, i)
    end
    return nil
end
local function IsHealSkill(id, key)
    if key and type(sv.heal) == "table" and sv.heal[key] then return true end
    if id and type(sv.healId) == "table" and sv.healId[tostring(id)] then return true end
    return false
end

local function DiagUpdate()                                  -- called only when an event happens
    if not DIAG or not diagLabel then return end
    local r, p = D.recv, D.play
    Try(diagLabel.SetText, diagLabel, string.format(
        "CM 0.6.1  UI %d/7  EV %s/%s/%s\n" ..
        "RECV a%d s%d u%d h%d k%d H%d G%d\n" ..
        "PLAY a%d s%d u%d h%d k%d H%d G%d\n" ..
        "DROP %d  OLD %d  HOLD %d\n" ..
        "STALE tmr %d  stop %d/%d  cp=%s\n" ..
        "ERR %d %s\n" ..
        "dT %d/%d ms  F%d\n" ..
        "IDLE built %d  runs %d  vis %s  react vis %s\n" ..
        "HEAL %s  zero %d\n" ..
        "GUARD %s\n" ..
        "HSKILL id %s  key %s  match %d  reg %d\n" ..
        "SHOW %s  LOAD %s",
        D.built, D.evSlot, D.evHit, D.evHeal,
        r.attack, r.skill, r.ult, r.hit, r.kill, r.heal, r.guard,
        p.attack, p.skill, p.ult, p.hit, p.kill, p.heal, p.guard,
        D.drop, D.oldlock, D.hold,
        D.staleT, D.stopIgn, D.stopAll, D.cp,
        D.err, D.lastErr,
        D.dtLast, D.dtMax, D.font,
        D.idleB, D.idleN, D.idleVis, D.rVis,
        D.lastHeal, D.healZero, D.lastGuard,
        D.hsId, D.hsKey, D.hsMatch, RegCount(),
        ShownStates(), LoadedStates()))
end

local function ApplyLayout()
    if not tlw then return end
    local h = sv.size
    local w = h                                           -- square 256x256 cells
    local x, y = sv.x, sv.y
    local sw, sh = ScreenSize()
    x = math.min(x, math.max(0, sw - w))
    y = math.min(y, math.max(0, sh - h))
    pcall(function()
        tlw:ClearAnchors()
        tlw:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
        tlw:SetDimensions(w, h)
    end)
end

local function FirstCell(e)
    Try(e.ctrl.SetTextureCoords, e.ctrl, 0, 1 / e.cols, 0, 1 / e.rows)
end

-- one-shot finished: keep showing the LAST cell (never the whole sheet, never blank)
local function HoldLastFrame(e)
    Try(e.ctrl.SetTextureCoords, e.ctrl, (e.cols - 1) / e.cols, 1, (e.rows - 1) / e.rows, 1)
end

-- waiting picture: one-shot timeline restarted by a timer while no reaction is playing
local function StopIdle()
    idleTok = idleTok + 1                                 -- any pending restart timer becomes stale
    if not idle then return end
    Try(idle.tl.Stop, idle.tl)
    Try(idle.ctrl.SetHidden, idle.ctrl, true)
end

local function StartIdleAnim()                            -- no closure: started through Try()
    idle.ctrl:SetTextureCoords(0, 1 / IDLE.cols, 0, 1 / IDLE.rows)
    idle.ctrl:SetHidden(false)
    idle.tl:SetPlaybackType(ANIMATION_PLAYBACK_ONE_SHOT)
    idle.tl:PlayFromStart()
end

local ShowIdle
local function IdleRound(my)
    if my ~= idleTok or cur ~= nil or not sv.enabled or not idle then return end   -- stale / a reaction is playing
    Try(StartIdleAnim)
    D.idleN = D.idleN + 1
    zo_callLater(function() IdleRound(my) end, IDLE_MS)
end

ShowIdle = function()
    if not idle or cur ~= nil then return end
    idleTok = idleTok + 1
    if not sv.enabled then StopIdle() return end
    IdleRound(idleTok)
end

local function EndReaction()
    local k = cur
    cur = nil                                             -- cleared first: an OnStop caused by the Stop below is ignored
    animUntil = 0
    if k then
        local e = E[k]
        if e then
            Try(e.tl.Stop, e.tl)
            Try(e.ctrl.SetHidden, e.ctrl, true)
        end
    end
    ShowIdle()                                            -- back to the waiting picture
    DiagUpdate()
end

local function BuildIdle()
    return Try(function()
        local c = WINDOW_MANAGER:CreateControl("CM_Tex_idle", tlw, CT_TEXTURE)
        c:SetAnchorFill(tlw)
        c:SetTexture(PATH .. IDLE.file)                   -- loaded once, reused
        c:SetHidden(true)
        Try(c.SetDrawLevel, c, 1)
        Try(c.SetAlpha, c, 1)
        local tl = ANIMATION_MANAGER:CreateTimeline()
        local anim = tl:InsertAnimation(ANIMATION_TEXTURE, c, 0)
        anim:SetImageData(IDLE.cols, IDLE.rows)
        anim:SetFramerate(IDLE.fps)
        anim:SetDuration(math.floor(IDLE.cols * IDLE.rows * 1000 / IDLE.fps))
        idle = { ctrl = c, tl = tl }
        D.idleB = 1
    end)
end

local function Build(key)
    local sh = SHEETS[key]
    return Try(function()
        local c = WINDOW_MANAGER:CreateControl("CM_Tex_" .. key, tlw, CT_TEXTURE)
        c:SetAnchorFill(tlw)
        c:SetTexture(PATH .. sh.file)                     -- loaded once, reused for every play
        c:SetHidden(true)
        Try(c.SetDrawLevel, c, 2)                         -- explicit: reactions above the waiting picture
        Try(c.SetAlpha, c, 1)
        local tl = ANIMATION_MANAGER:CreateTimeline()
        local anim = tl:InsertAnimation(ANIMATION_TEXTURE, c, 0)
        anim:SetImageData(sh.cols, sh.rows)
        anim:SetFramerate(FPS)
        anim:SetDuration(ANIM_MS)
        local e = { ctrl = c, tl = tl, cols = sh.cols, rows = sh.rows, at = 0 }
        -- OnStop cannot tell which play it belongs to, so the last frame is held ONLY when it is certain:
        -- this reaction is the current one, the timeline reports "finished" (== true) and the motion time has
        -- really elapsed since THIS play started. Anything else (our own Stop, a stale or unclear notice) is ignored.
        tl:SetHandler("OnStop", function(_, completedPlaying)
            D.stopAll = D.stopAll + 1
            D.cp = tostring(completedPlaying)
            if cur ~= key or completedPlaying ~= true
                or GetGameTimeMilliseconds() - e.at < ANIM_MS - STOP_TOL then
                D.stopIgn = D.stopIgn + 1
                return
            end
            D.hold = D.hold + 1
            HoldLastFrame(e)
        end)
        E[key] = e
    end)
end

-- no closure: started through Try()
local function StartAnim(e)
    e.ctrl:SetTextureCoords(0, 1 / e.cols, 0, 1 / e.rows)
    e.ctrl:SetHidden(false)
    e.tl:SetPlaybackType(ANIMATION_PLAYBACK_ONE_SHOT)
    e.tl:PlayFromStart()
end

-- force = true: used by the settings test play (ignores priority)
local function Play(key, force, fromCast)
    local e = E[key]
    if not e or not sv.enabled then return end
    local t0 = GetGameTimeMilliseconds()
    if not force then
        D.recv[key] = D.recv[key] + 1
        if lastStart > 0 and t0 < lastStart + TOTAL_MS then D.oldlock = D.oldlock + 1 end   -- v0.2.0 would have ignored it
    end
    -- heal is the lowest priority: it plays only when nothing else is playing (waiting picture only)
    if not force and key == "heal" and cur and not fromCast then
        D.drop = D.drop + 1
        DiagUpdate()
        return
    end
    -- motion phase: a lower priority never interrupts; equal / higher replaces; last-frame hold: anything replaces
    if not force and cur and t0 < animUntil and PRI[key] < PRI[cur] then
        D.drop = D.drop + 1
        DiagUpdate()
        return
    end
    if cur then
        if cur ~= key then                                -- switch to another reaction: stop and hide the old one
            local old = E[cur]
            if old then
                Try(old.tl.Stop, old.tl)
                Try(old.ctrl.SetHidden, old.ctrl, true)
            end
        else                                              -- same reaction again: clean restart from the first frame
            Try(e.tl.Stop, e.tl)
        end
    end
    StopIdle()                                            -- the waiting picture makes room for the reaction
    token = token + 1
    local my = token
    cur = key
    lastStart = t0
    animUntil = t0 + ANIM_MS
    e.at = t0
    if not Try(StartAnim, e) then EndReaction() DiagUpdate() return end
    zo_callLater(function()
        if my == token then EndReaction() else D.staleT = D.staleT + 1 end   -- stale timer: does nothing
    end, TOTAL_MS)
    D.play[key] = D.play[key] + 1
    Try(function()
        D.rVis = tostring(not e.ctrl:IsHidden())
        D.idleVis = idle and tostring(not idle.ctrl:IsHidden()) or "nil"
    end)
    local dt = GetGameTimeMilliseconds() - t0
    D.dtLast = dt
    if dt > D.dtMax then D.dtMax = dt end
    DiagUpdate()
end

-- diagnostic text under the mascot window (created only when DIAG; updated only by events)
local function BuildDiag()
    if not DIAG or not tlw then return end
    Try(function()
        local bg = WINDOW_MANAGER:CreateControl("CM_DiagBG", tlw, CT_BACKDROP)
        local lb = WINDOW_MANAGER:CreateControl("CM_DiagLabel", tlw, CT_LABEL)
        lb:SetAnchor(TOPLEFT, tlw, BOTTOMLEFT, 0, 6)
        lb:SetDimensions(560, 400)
        -- big font first; a name that does not exist as a font object is skipped. F1..F4 on screen = which one was used
        local fonts = { "ZoFontGamepad27", "ZoFontGamepad22", "ZoFontGame", "ZoFontGameSmall" }
        local pick = #fonts
        for i, name in ipairs(fonts) do
            if _G[name] ~= nil then pick = i break end
        end
        D.font = pick
        lb:SetFont(fonts[pick])
        lb:SetColor(1, 1, 1, 1)
        lb:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        lb:SetVerticalAlignment(TEXT_ALIGN_TOP)
        lb:SetText("CM 0.6.1\n(waiting for events)")
        bg:SetAnchorFill(lb)
        bg:SetCenterColor(0, 0, 0, 0.65)
        bg:SetEdgeColor(0, 0, 0, 0)
        diagLabel = lb
    end)
end

------------------------------------------------------------------
-- Events (UNCHANGED from v0.1.0)
------------------------------------------------------------------
local ULT_SLOT = 8
if ACTION_BAR_ULTIMATE_SLOT_INDEX ~= nil then
    ULT_SLOT = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1         -- read at run time (PS5: constant 7 -> slot 8)
end

-- slot 1/2 = weapon attack input (light/heavy mapping not confirmed; shared reaction),
-- slots 3 .. ULT_SLOT-1 = skills, ULT_SLOT = ultimate
local function OnSlotUsed(_, slotNum)
    if slotNum == 1 or slotNum == 2 then Play("attack") return end
    if slotNum == ULT_SLOT then Play("ult") return end
    if slotNum ~= nil and slotNum >= 3 and slotNum < ULT_SLOT then
        local id, key
        pcall(function() id = GetSlotBoundId(slotNum); key = SkillKey(id) end)
        lastSkill.id, lastSkill.key = id, key
        D.hsId, D.hsKey = tostring(id), key or "-"
        if IsHealSkill(id, key) then
            D.hsMatch = D.hsMatch + 1
            Play("heal", false, true)                         -- registered heal skill: heal reaction instead of the skill one
        else
            Play("skill")
        end
    end
end

-- Damage taken: direct damage whose source is not the player (unchanged). v0.5.0: block / dodge / shield absorb on the
-- player share one "guard" reaction (results observed on PS5 with v0.4.3b: BLOCKED_DAMAGE, DODGED, DAMAGE_SHIELDED).
local R_BLOCK, R_DODGE, R_SHIELD = ACTION_RESULT_BLOCKED_DAMAGE, ACTION_RESULT_DODGED, ACTION_RESULT_DAMAGE_SHIELDED
local function OnCombat(_, result, isError, _, _, _, _, sourceType, _, _, hitValue, _, _, _, _, _, abilityId)
    if isError then return end
    if result == ACTION_RESULT_DAMAGE or result == ACTION_RESULT_CRITICAL_DAMAGE then
        if sourceType == COMBAT_UNIT_TYPE_PLAYER then return end
        Play("hit")
        return
    end
    if result == R_BLOCK or result == R_DODGE or result == R_SHIELD then
        D.lastGuard = string.format("r%s id%s v%s", tostring(result), tostring(abilityId), tostring(hitValue))
        Play("guard")
    end
end

-- Own direct heal only: result HEAL with the player as source. Crit heal / HoT have other result codes and are not
-- connected; a heal from someone else has another source. Registered with a source filter (same pattern as v0.4.3b).
local function OnHeal(_, result, isError, _, _, _, _, sourceType, _, _, hitValue, _, _, _, _, _, abilityId)
    if isError or result ~= ACTION_RESULT_HEAL then return end
    if sourceType ~= COMBAT_UNIT_TYPE_PLAYER then return end
    D.lastHeal = string.format("id%s v%s", tostring(abilityId), tostring(hitValue))
    if hitValue == 0 then D.healZero = D.healZero + 1 end
    Play("heal")
end

local function RegisterEvents()
    D.evSlot = pcall(function()
        EVENT_MANAGER:RegisterForEvent(ADDON .. "_Slot", EVENT_ACTION_SLOT_ABILITY_USED, OnSlotUsed)
    end) and "ok" or "NG"
    if REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE ~= nil and COMBAT_UNIT_TYPE_PLAYER ~= nil then
        D.evHit = pcall(function()
            EVENT_MANAGER:RegisterForEvent(ADDON .. "_Hit", EVENT_COMBAT_EVENT, OnCombat)
            EVENT_MANAGER:AddFilterForEvent(ADDON .. "_Hit", EVENT_COMBAT_EVENT,
                REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
        end) and "ok" or "NG"
    else
        D.evHit = "n/a"
    end
    if REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE ~= nil and COMBAT_UNIT_TYPE_PLAYER ~= nil and ACTION_RESULT_HEAL ~= nil then
        D.evHeal = pcall(function()
            EVENT_MANAGER:RegisterForEvent(ADDON .. "_Heal", EVENT_COMBAT_EVENT, function(...) Try(OnHeal, ...) end)
            EVENT_MANAGER:AddFilterForEvent(ADDON .. "_Heal", EVENT_COMBAT_EVENT,
                REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
        end) and "ok" or "NG"
    else
        D.evHeal = "n/a"
    end
    -- Enemy kill: detection method not decided yet -> no event is connected (asset + Play("kill") are ready).
end

------------------------------------------------------------------
-- Preview (runtime only): the window stays visible in menus so position / size can be adjusted
------------------------------------------------------------------
local function SetPreview(on)
    preview = on and true or false
    if hudFragment and tlw then
        pcall(function()
            if preview then
                HUD_SCENE:RemoveFragment(hudFragment)
                HUD_UI_SCENE:RemoveFragment(hudFragment)
                tlw:SetHidden(false)
            else
                HUD_SCENE:AddFragment(hudFragment)
                HUD_UI_SCENE:AddFragment(hudFragment)
                local inHud = SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui")
                tlw:SetHidden(not inHud)
            end
        end)
    end
    ShowIdle()
end

-- diagnostic: show the FIRST cell of one sheet with no timeline at all (does the picture draw by itself?)
local function StaticShow(which)
    token = token + 1                                     -- stale timers do nothing
    cur = nil
    animUntil = 0
    for _, k in ipairs(ORDER) do
        local e = E[k]
        if e then
            Try(e.tl.Stop, e.tl)
            Try(e.ctrl.SetHidden, e.ctrl, true)
        end
    end
    StopIdle()
    local c, cols, rows
    if which == "idle" and idle then
        c, cols, rows = idle.ctrl, IDLE.cols, IDLE.rows
    elseif E.attack then
        c, cols, rows = E.attack.ctrl, E.attack.cols, E.attack.rows
    end
    if c then
        Try(c.SetTextureCoords, c, 0, 1 / cols, 0, 1 / rows)
        Try(c.SetHidden, c, false)
    end
    DiagUpdate()
end

------------------------------------------------------------------
-- Settings panel (LibAddonMenu-2.0 is OPTIONAL)
------------------------------------------------------------------
local function ResetToDefaults()
    sv.enabled, sv.x, sv.y, sv.size = DEFAULTS.enabled, DEFAULTS.x, DEFAULTS.y, DEFAULTS.size
    ApplyLayout()
    ShowIdle()
end

local TEST_CHOICES = {
    "-",
    "えいっ！ (Attack)",
    "魔法発動！ (Skill)",
    "どっか〜ん！ (Ultimate)",
    "ふぎゃっ！ (Hit)",
    "やったね！ (Kill)",
    "[静止] 待機 1コマ目",
    "[静止] えいっ 1コマ目",
    "元気にな〜れ♪ (Heal)",
    "効かないよ〜だ！ (Guard)",
}
local TEST_KEY = {
    [TEST_CHOICES[2]] = "attack", [TEST_CHOICES[3]] = "skill", [TEST_CHOICES[4]] = "ult",
    [TEST_CHOICES[5]] = "hit",    [TEST_CHOICES[6]] = "kill",
    [TEST_CHOICES[9]] = "heal",   [TEST_CHOICES[10]] = "guard",
}

local function BuildSettings()
    local LAM = LibAddonMenu2
    if not LAM then return end                            -- no LAM: defaults are used, nothing else to do

    local panelName = ADDON .. "_Panel"
    local panel = LAM:RegisterAddonPanel(panelName, {
        type = "panel",
        name = "CombatMascot",
        displayName = "CombatMascot",
        author = "CombatMascot project",
        version = VERSION,
    })

    local function Refresh()
        pcall(function() CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", panel) end)
    end

    local sw, sh = ScreenSize()
    sw, sh = math.max(200, math.floor(sw)), math.max(200, math.floor(sh))

    LAM:RegisterOptionControls(panelName, {
        {
            type = "checkbox", name = "Show Mascot (表示)",
            getFunc = function() return sv.enabled end,
            setFunc = function(v) sv.enabled = v and true or false; ApplyLayout(); if not sv.enabled then StopIdle() else ShowIdle() end end,
            default = DEFAULTS.enabled,
        },
        {
            type = "checkbox", name = "Preview while in menus (プレビュー表示)",
            tooltip = "ON: the mascot stays visible while this settings screen is open, so you can place it. Turns OFF again at the next login.",
            getFunc = function() return preview end,
            setFunc = function(v) SetPreview(v) end,
            default = false,
        },
        {
            type = "slider", name = "Position X (横位置)", min = 0, max = sw, step = 10,
            getFunc = function() return sv.x end,
            setFunc = function(v) sv.x = Num(v, 0, 8000, DEFAULTS.x); ApplyLayout() end,
            default = DEFAULTS.x,
        },
        {
            type = "slider", name = "Position Y (縦位置)", min = 0, max = sh, step = 10,
            getFunc = function() return sv.y end,
            setFunc = function(v) sv.y = Num(v, 0, 8000, DEFAULTS.y); ApplyLayout() end,
            default = DEFAULTS.y,
        },
        {
            type = "slider", name = "Size (大きさ)", min = SIZE_MIN, max = SIZE_MAX, step = SIZE_STEP,
            getFunc = function() return sv.size end,
            setFunc = function(v) sv.size = Num(v, SIZE_MIN, SIZE_MAX, DEFAULTS.size); ApplyLayout() end,
            default = DEFAULTS.size,
        },
        {
            type = "button", name = "Reset to defaults (初期値に戻す)",
            tooltip = "Resets show / position / size to the default values.",
            func = function() ResetToDefaults(); Refresh() end,
        },
        {
            type = "description",
            text = function()
                return string.format("直前に使ったスキル: id=%s 系列=%s / 登録数 %d (系列API: %s)",
                    tostring(lastSkill.id), lastSkill.key or "-", RegCount(),
                    GetSpecificSkillAbilityKeysByAbilityId ~= nil and "有" or "無")
            end,
        },
        {
            type = "button", name = "直前に使ったスキルを回復として登録",
            tooltip = "回復スキルを1回使ってからこのボタンを押すと、そのスキルの系列(モーフ違い含む)が回復演出の対象になります。",
            func = function()
                if lastSkill.id then
                    if lastSkill.key then sv.heal[lastSkill.key] = true end
                    sv.healId[tostring(lastSkill.id)] = true
                end
                DiagUpdate(); Refresh()
            end,
        },
        {
            type = "button", name = "回復スキルの登録をすべて消す",
            func = function() sv.heal = {}; sv.healId = {}; DiagUpdate(); Refresh() end,
        },
        {
            type = "dropdown", name = "Test play (演出テスト再生)",
            tooltip = "Plays the chosen reaction once (the preview is switched on automatically so it is visible here). It returns to the waiting picture afterwards.",
            choices = TEST_CHOICES,
            getFunc = function() return TEST_CHOICES[1] end,
            setFunc = function(choice)
                local key = TEST_KEY[choice]
                if choice == TEST_CHOICES[7] then
                    SetPreview(true)
                    StaticShow("idle")
                elseif choice == TEST_CHOICES[8] then
                    SetPreview(true)
                    StaticShow("attack")
                elseif key then
                    SetPreview(true)
                    Play(key, true)
                end
                Refresh()
            end,
            default = TEST_CHOICES[1],
        },
    })
end

------------------------------------------------------------------
-- Start-up
------------------------------------------------------------------
local started = false

local function BuildUI()
    local ok = pcall(function()
        tlw = WINDOW_MANAGER:CreateTopLevelWindow("CM_TLW")
        tlw:SetMouseEnabled(false)
        tlw:SetMovable(false)
    end)
    if not ok or not tlw then tlw = nil return false end
    ApplyLayout()
    BuildIdle()                                           -- first = drawn below every reaction
    for _, key in ipairs(ORDER) do if Build(key) then D.built = D.built + 1 end end   -- one failing sheet does not stop the others
    BuildDiag()
    -- Show only on the HUD (hide in menus). If this fails the window simply stays visible everywhere.
    pcall(function()
        hudFragment = ZO_SimpleSceneFragment:New(tlw)
        HUD_SCENE:AddFragment(hudFragment)
        HUD_UI_SCENE:AddFragment(hudFragment)
    end)
    return true
end

local function OnPlayerActivated()
    if started then ShowIdle() return end                 -- later activations (zoning / reload): restart the loop
    started = true
    if not BuildUI() then return end
    RegisterEvents()
    ShowIdle()
    DiagUpdate()
end

local function OnAddOnLoaded(_, name)
    if name ~= ADDON then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON .. "_Load", EVENT_ADD_ON_LOADED)

    -- saved settings: any failure or invalid value falls back to the defaults
    local ok = pcall(function()
        local namespace = GetWorldName and GetWorldName() or nil
        sv = ZO_SavedVars:NewAccountWide(SV_NAME, SV_VERSION, namespace, DEFAULTS)
    end)
    if not ok or type(sv) ~= "table" then
        sv = { enabled = DEFAULTS.enabled, x = DEFAULTS.x, y = DEFAULTS.y, size = DEFAULTS.size }
    end
    Sanitize()

    EVENT_MANAGER:RegisterForEvent(ADDON .. "_Act", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    pcall(BuildSettings)                                  -- a settings failure never stops the mascot
end

EVENT_MANAGER:RegisterForEvent(ADDON .. "_Load", EVENT_ADD_ON_LOADED, OnAddOnLoaded)
