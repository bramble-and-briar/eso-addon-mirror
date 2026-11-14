-- CombatMascotDiag v0.1.2
-- v0.1.2: result names via explicit constant references (the _G scan failed on PS5), source-type of
--         taken hits + self-overlap counters, ability cost for every slot use, IsAbilityUltimate evidence.
--         DDS / animation / interrupt code is unchanged since v0.1.0.
-- v0.1.1: ULT candidate slot (const+1), skill = slots 3-7, slot 1/2 counted separately,
--         per-result-code counters (names from the game's own ACTION_RESULT_* constants),
--         cheaper event handlers. DDS / animation / interrupt code is unchanged from v0.1.0.
-- PS5/CS diagnostic ONLY. Not the CombatMascot addon.
-- No libraries, no OnUpdate, no SavedVariables, no chat output.
-- Every ESO API call below is wrapped in pcall; the result is shown on screen.
-- Nothing here is "verified on PS5" until the player confirms it on the console.

local ADDON = "CombatMascotDiag"
local PATH  = "CombatMascotDiag/"
local VERSION = "0.1.2"
local FPS = 12                       -- test frame rate for every sheet

------------------------------------------------------------------
-- State shown on the single diagnostic screen
------------------------------------------------------------------
local S = {
    seq = "waiting for PLAYER_ACTIVATED",
    errCount = 0, err = nil,
    api = {},                        -- api[name] = "Y" | "N" | "ERR"
    load = {},                       -- load[key] = { "-","-","-", cbMs=nil, dim=nil }
    inter = { i1 = "-", i2 = "-", i3 = "-", all = "-" },
    reg = { src = "-", tgt = "-", slot = "-" },
    c = { light = 0, heavy = 0, skill = 0, ultCand = 0, kill = 0,
          s1 = 0, s2 = 0, slotOther = 0,
          hitFromSelf = 0, hitFromOther = 0, srcToSelf = 0, tgtFromSelf = 0,
          hitDirect = 0, hitDot = 0, hitShield = 0, hitOther = 0,
          src = 0, tgt = 0, slot = 0 },
    slotCnt = {},                    -- slotCnt[slotNum] = count
    slotCost = {},                   -- slotCost[slotNum] = last cost text (GetSlotAbilityCost 1st return)
    resSrc = {}, resTgt = {},        -- resSrc[resultCode] = count (classification counters)
    last = { srcLine = "-", tgtLine = "-", slotLine = "-", ultLine = "-" },
}

local started = false
local root, bg, label
local Refresh                         -- forward declaration
local dirty = false

local function Now() return GetGameTimeMilliseconds() end

local function Dirty()
    if dirty then return end
    dirty = true
    zo_callLater(function() Refresh() end, 500)   -- at most ~2 redraws/second, change-driven
end

-- low-rate redraw request for events that are only counted (classification counters)
local slowPending = false
local function DirtySlow()
    if slowPending then return end
    slowPending = true
    zo_callLater(function() slowPending = false; Dirty() end, 2000)
end

local function Err(where, msg)
    S.errCount = S.errCount + 1
    S.err = where .. ": " .. string.sub(tostring(msg), 1, 90)
    Dirty()
end

-- pcall wrapper that records the API status under 'name'
local function Probe(name, fn)
    local ok, a, b = pcall(fn)
    if ok then
        if S.api[name] ~= "ERR" then S.api[name] = "Y" end
    else
        S.api[name] = "ERR"
        Err(name, a)
    end
    return ok, a, b
end

------------------------------------------------------------------
-- Sheets (test textures)
------------------------------------------------------------------
local SHEETS = {
    A = { file = "CMD_A_2x2.dds",   cols = 2, rows = 2, cells = 4, label = "A 2x2 (4f)" },
    B = { file = "CMD_B_4x2.dds",   cols = 4, rows = 2, cells = 8, label = "B 4x2 (5f+3 hold)" },
    C = { file = "CMD_C_4x2h4.dds", cols = 4, rows = 2, cells = 8, label = "C 4x2 (4f+4 hold)" },
    M = { file = "CMD_MISSING.dds", cols = 4, rows = 2, cells = 8, label = "M missing file" },
}
local ORDER = { "A", "B", "C", "M" }

local function CycleMs(sh) return math.floor(sh.cells * 1000 / FPS + 0.5) end

local curRow = nil                    -- row of the play test that is currently running

local function IsLoaded(sh)
    if not sh.ctrl or type(sh.ctrl.IsTextureLoaded) ~= "function" then return "NA" end
    local ok, v = pcall(sh.ctrl.IsTextureLoaded, sh.ctrl)
    if not ok then return "ERR" end
    return v and "Y" or "N"
end

local function StaticFirstCell(sh)
    if not sh.ctrl then return end
    pcall(function() sh.ctrl:SetTextureCoords(0, 1 / sh.cols, 0, 1 / sh.rows) end)
end

local function HiddenState(sh)
    if not sh.ctrl then return true end
    local ok, h = pcall(function() return sh.ctrl:IsHidden() end)
    if not ok then return true end
    return h
end

------------------------------------------------------------------
-- UI (single screen; created once)
------------------------------------------------------------------
local function BuildUI()
    local wm = WINDOW_MANAGER
    local ok, e = pcall(function()
        root = wm:CreateTopLevelWindow("CMD_Root")
        root:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 0, 0)
        root:SetDimensions(GuiRoot:GetWidth(), GuiRoot:GetHeight())
        root:SetMouseEnabled(false)
        root:SetHidden(false)
    end)
    if not ok then Err("CreateTopLevelWindow", e) return false end

    pcall(function()
        bg = wm:CreateControl("CMD_Bg", root, CT_BACKDROP)
        bg:SetAnchor(TOPLEFT, root, TOPLEFT, 20, 20)
        bg:SetDimensions(1180, 700)
        bg:SetCenterColor(0, 0, 0, 0.78)
        bg:SetEdgeColor(0, 0, 0, 0)
    end)

    local ok2, e2 = pcall(function()
        label = wm:CreateControl("CMD_Text", root, CT_LABEL)
        label:SetAnchor(TOPLEFT, root, TOPLEFT, 32, 28)
        label:SetFont("ZoFontGamepad18")
        label:SetColor(1, 1, 1, 1)
        label:SetText("CombatMascotDiag starting...")
    end)
    if not ok2 then Err("CreateLabel", e2) end

    for i, k in ipairs(ORDER) do
        local sh = SHEETS[k]
        pcall(function()
            local c = wm:CreateControl("CMD_Tex" .. k, root, CT_TEXTURE)
            c:SetDimensions(140, 140)
            c:SetAnchor(TOPRIGHT, root, TOPRIGHT, -40 - (#ORDER - i) * 150, 40)
            c:SetHidden(true)
            sh.ctrl = c
            local l = wm:CreateControl("CMD_TexLbl" .. k, root, CT_LABEL)
            l:SetFont("ZoFontGamepad18")
            l:SetColor(1, 1, 1, 1)
            l:SetText(k)
            l:SetAnchor(TOP, c, BOTTOM, 0, 4)
        end)
    end
    return true
end

------------------------------------------------------------------
-- Timeline per animated sheet (ANIMATION_TEXTURE)
------------------------------------------------------------------
local function BuildTimeline(key)
    local sh = SHEETS[key]
    if not sh.ctrl then return end
    local ok, tl = Probe("CreateTimeline", function() return ANIMATION_MANAGER:CreateTimeline() end)
    if not ok or not tl then return end
    local ok2, anim = Probe("InsertAnimation(ANIMATION_TEXTURE)", function()
        return tl:InsertAnimation(ANIMATION_TEXTURE, sh.ctrl, 0)
    end)
    if not ok2 or not anim then return end
    Probe("SetImageData", function() anim:SetImageData(sh.cols, sh.rows) end)
    Probe("SetFramerate", function() anim:SetFramerate(FPS) end)
    Probe("SetDuration", function() anim:SetDuration(CycleMs(sh)) end)
    Probe("SetHandler(OnStop)", function()
        tl:SetHandler("OnStop", function()
            if curRow and not curRow.onStopMs then curRow.onStopMs = Now() end
        end)
    end)
    sh.tl, sh.anim = tl, anim
end

local function SetMode(sh, loop)
    if loop then
        Probe("SetPlaybackType(LOOP)", function()
            sh.tl:SetPlaybackType(ANIMATION_PLAYBACK_LOOP, LOOP_INDEFINITELY)
        end)
    else
        Probe("SetPlaybackType(ONE_SHOT)", function()
            sh.tl:SetPlaybackType(ANIMATION_PLAYBACK_ONE_SHOT)
        end)
    end
end

local function StartAnim(sh, loop)
    if not sh.tl then return false end
    pcall(function() sh.ctrl:SetHidden(false) end)
    SetMode(sh, loop)
    sh.startMs = Now()
    local ok = Probe("PlayFromStart", function() sh.tl:PlayFromStart() end)
    return ok
end

local function StopAnim(sh)
    if sh.tl then Probe("Stop", function() sh.tl:Stop() end) end
    StaticFirstCell(sh)
end

local function IsPlaying(sh)
    if not sh.tl then return "NA" end
    local ok, v = Probe("IsPlaying", function() return sh.tl:IsPlaying() end)
    if not ok then return "ERR" end
    return v and "Y" or "N"
end

------------------------------------------------------------------
-- Play tests (automatic, time-based, no OnUpdate)
------------------------------------------------------------------
local TESTS = {
    { id = "A 1shot",     key = "A", loop = false, exp = 333 },
    { id = "B 1shot",     key = "B", loop = false, exp = 667 },
    { id = "C 1shot",     key = "C", loop = false, exp = 667 },
    { id = "A loop@333",  key = "A", loop = true,  hideAt = 333 },
    { id = "A loop@1000", key = "A", loop = true,  hideAt = 1000, probeAt = 700 },
    { id = "B loop@550",  key = "B", loop = true,  hideAt = 550 },
    { id = "C loop@500",  key = "C", loop = true,  hideAt = 500 },
}

local function RunTest(row, done)
    local sh = SHEETS[row.key]
    curRow = row
    row.state = "running"
    if not StartAnim(sh, row.loop) then
        row.state = "start failed"
        curRow = nil
        Dirty()
        zo_callLater(done, 300)
        return
    end
    Dirty()
    if not row.loop then
        zo_callLater(function()
            row.playingAfter = IsPlaying(sh)          -- expected N once the one-shot has ended
            row.stopMs = row.onStopMs and (row.onStopMs - sh.startMs) or nil
            row.state = "ended (look: which number stays?)"
            Dirty()
        end, row.exp + 150)
        zo_callLater(function()                          -- let the final frame stay visible, then reset
            curRow = nil
            StopAnim(sh)
            pcall(function() sh.ctrl:SetHidden(true) end)
            row.state = "done"
            Dirty()
            done()
        end, row.exp + 1300)
    else
        if row.probeAt then
            zo_callLater(function() row.probe = IsPlaying(sh) Dirty() end, row.probeAt)
        end
        zo_callLater(function()
            row.playingAtHide = IsPlaying(sh)             -- Y means the timeline was still looping
            row.hideActual = Now() - sh.startMs
            curRow = nil                                   -- our own Stop() must not count as OnStop
            StopAnim(sh)
            pcall(function() sh.ctrl:SetHidden(true) end)
            row.state = "done"
            Dirty()
            zo_callLater(done, 400)
        end, row.hideAt)
    end
end

------------------------------------------------------------------
-- Interrupt controller (the logic CombatMascot would use) + test
------------------------------------------------------------------
local ctl = { token = 0, prio = 0, curKey = nil, endAt = 0, rejected = 0,
              stale = 0, staleSawNew = nil }

local function CtlReset()
    ctl.token, ctl.prio, ctl.curKey, ctl.endAt = 0, 0, nil, 0
    ctl.rejected, ctl.stale, ctl.staleSawNew = 0, 0, nil
end

local function CtlOnEnd(myToken, key)
    if myToken ~= ctl.token then
        -- stale timer from an interrupted playback: must NOT touch the new playback
        ctl.stale = ctl.stale + 1
        local cur = ctl.curKey and SHEETS[ctl.curKey]
        ctl.staleSawNew = (cur ~= nil) and (not HiddenState(cur)) and true or false
        Dirty()
        return
    end
    local sh = SHEETS[key]
    StopAnim(sh)
    pcall(function() sh.ctrl:SetHidden(true) end)
    ctl.prio, ctl.curKey = 0, nil
    Dirty()
end

-- returns true if accepted, false if discarded (no queue)
local function CtlPlay(key, prio)
    local now = Now()
    local busy = ctl.prio > 0 and now < ctl.endAt
    if busy and prio <= ctl.prio then
        ctl.rejected = ctl.rejected + 1
        return false
    end
    if ctl.curKey then
        local old = SHEETS[ctl.curKey]
        StopAnim(old)
        pcall(function() old.ctrl:SetHidden(true) end)
    end
    ctl.token = ctl.token + 1
    local my = ctl.token
    local sh = SHEETS[key]
    local dur = CycleMs(sh)
    ctl.prio, ctl.curKey, ctl.endAt = prio, key, now + dur
    StartAnim(sh, false)
    zo_callLater(function() CtlOnEnd(my, key) end, dur)
    return true
end

local function RunInterrupt(done)
    S.seq = "interrupt test"
    CtlReset()
    S.inter = { i1 = "...", i2 = "...", i3 = "...", all = "..." }
    Dirty()
    local a = CtlPlay("A", 1)                                   -- t=0   low priority starts
    zo_callLater(function() CtlPlay("B", 3) end, 150)           -- t=150 higher priority interrupts
    zo_callLater(function()                                     -- t=373: A's stale timer (333) has fired
        local ok = a and ctl.stale == 1 and ctl.staleSawNew == true and ctl.token == 2
                   and (not HiddenState(SHEETS.B)) and HiddenState(SHEETS.A)
        S.inter.i1 = ok and "PASS" or "FAIL"
        Dirty()
    end, 373)
    zo_callLater(function()                                     -- t=400: lower, then equal -> discarded
        local r1 = CtlPlay("C", 2)
        local r2 = CtlPlay("B", 3)
        local ok = (r1 == false) and (r2 == false) and ctl.rejected == 2
                   and HiddenState(SHEETS.C) and ctl.token == 2
        S.inter.i2 = ok and "PASS" or "FAIL"
        Dirty()
    end, 400)
    zo_callLater(function()                                     -- after B ended (150+667) -> idle
        local ok = ctl.prio == 0 and ctl.curKey == nil and ctl.token == 2
                   and HiddenState(SHEETS.A) and HiddenState(SHEETS.B) and HiddenState(SHEETS.C)
        S.inter.i3 = ok and "PASS" or "FAIL"
        S.inter.all = (S.inter.i1 == "PASS" and S.inter.i2 == "PASS" and S.inter.i3 == "PASS") and "PASS" or "FAIL"
        Dirty()
        done()
    end, 150 + 667 + 150)
end

------------------------------------------------------------------
-- Combat event diagnostics (filtered, event-driven)
------------------------------------------------------------------
local RESULT_NAMES = {}
local function AddName(tbl, const, name) if const ~= nil then tbl[const] = name end end
AddName(RESULT_NAMES, ACTION_RESULT_DAMAGE, "DMG")
AddName(RESULT_NAMES, ACTION_RESULT_CRITICAL_DAMAGE, "CRIT")
AddName(RESULT_NAMES, ACTION_RESULT_DOT_TICK, "DOT")
AddName(RESULT_NAMES, ACTION_RESULT_DOT_TICK_CRITICAL, "DOTCRIT")
AddName(RESULT_NAMES, ACTION_RESULT_DAMAGE_SHIELDED, "SHIELDED")
AddName(RESULT_NAMES, ACTION_RESULT_KILLING_BLOW, "KILLBLOW")
-- Names come from the game's own ACTION_RESULT_* globals (scanned once at start-up).
-- A code with no such global stays "r<number>" and is NOT interpreted.
local RNAME = {}
local function BuildResultNames()
    -- Direct global reads (no _G scan: that failed on PS5 in v0.1.1). A missing constant is simply nil.
    local KNOWN = {
        { "DAMAGE", ACTION_RESULT_DAMAGE }, { "CRITICAL_DAMAGE", ACTION_RESULT_CRITICAL_DAMAGE },
        { "DOT_TICK", ACTION_RESULT_DOT_TICK }, { "DOT_TICK_CRITICAL", ACTION_RESULT_DOT_TICK_CRITICAL },
        { "DAMAGE_SHIELDED", ACTION_RESULT_DAMAGE_SHIELDED }, { "BLOCKED_DAMAGE", ACTION_RESULT_BLOCKED_DAMAGE },
        { "KILLING_BLOW", ACTION_RESULT_KILLING_BLOW }, { "DIED", ACTION_RESULT_DIED }, { "DIED_XP", ACTION_RESULT_DIED_XP },
        { "HEAL", ACTION_RESULT_HEAL }, { "CRITICAL_HEAL", ACTION_RESULT_CRITICAL_HEAL },
        { "HOT_TICK", ACTION_RESULT_HOT_TICK }, { "HOT_TICK_CRITICAL", ACTION_RESULT_HOT_TICK_CRITICAL },
        { "EFFECT_GAINED", ACTION_RESULT_EFFECT_GAINED }, { "EFFECT_GAINED_DURATION", ACTION_RESULT_EFFECT_GAINED_DURATION },
        { "EFFECT_FADED", ACTION_RESULT_EFFECT_FADED }, { "BEGIN", ACTION_RESULT_BEGIN },
        { "BEGIN_CHANNEL", ACTION_RESULT_BEGIN_CHANNEL }, { "INTERRUPT", ACTION_RESULT_INTERRUPT },
        { "STUNNED", ACTION_RESULT_STUNNED }, { "MISS", ACTION_RESULT_MISS }, { "DODGED", ACTION_RESULT_DODGED },
        { "REFLECTED", ACTION_RESULT_REFLECTED }, { "ABSORBED", ACTION_RESULT_ABSORBED }, { "IMMUNE", ACTION_RESULT_IMMUNE },
        { "POWER_ENERGIZE", ACTION_RESULT_POWER_ENERGIZE }, { "POWER_DRAIN", ACTION_RESULT_POWER_DRAIN },
        { "ABILITY_ON_COOLDOWN", ACTION_RESULT_ABILITY_ON_COOLDOWN }, { "FALL_DAMAGE", ACTION_RESULT_FALL_DAMAGE },
        { "PRECISE_DAMAGE", ACTION_RESULT_PRECISE_DAMAGE }, { "WRECKING_DAMAGE", ACTION_RESULT_WRECKING_DAMAGE },
        { "SNARED", ACTION_RESULT_SNARED }, { "ROOTED", ACTION_RESULT_ROOTED }, { "KNOCKBACK", ACTION_RESULT_KNOCKBACK },
    }
    local found = 0
    for i = 1, #KNOWN do
        local nm, v = KNOWN[i][1], KNOWN[i][2]
        if type(v) == "number" then
            local cur = RNAME[v]
            if cur == nil then RNAME[v] = nm; found = found + 1
            elseif nm < cur then RNAME[v] = nm end
        end
    end
    S.api.resultNames = "Y(" .. found .. "/" .. #KNOWN .. ")"
end
local function ResName(r) return RNAME[r] or RESULT_NAMES[r] or ("r" .. tostring(r)) end

-- Rough grouping by constant NAME only (heuristic, not a game-defined category)
local function ClassOf(code)
    local nm = RNAME[code]
    if not nm then return "unknown" end
    if string.find(nm, "DAMAGE", 1, true) or string.find(nm, "DOT_TICK", 1, true) then return "dmg" end
    if string.find(nm, "HEAL", 1, true) or string.find(nm, "HOT_TICK", 1, true) then return "heal" end
    if string.find(nm, "EFFECT_GAINED", 1, true) or string.find(nm, "EFFECT_FADED", 1, true) then return "effect" end
    if string.find(nm, "KILLING_BLOW", 1, true) or string.find(nm, "DIED", 1, true) then return "death" end
    return "other"
end

local function SlotTypeName(t)
    if t == nil then return "nil" end
    if ACTION_SLOT_TYPE_LIGHT_ATTACK ~= nil and t == ACTION_SLOT_TYPE_LIGHT_ATTACK then return "LIGHT" end
    if ACTION_SLOT_TYPE_HEAVY_ATTACK ~= nil and t == ACTION_SLOT_TYPE_HEAVY_ATTACK then return "HEAVY" end
    return "t" .. tostring(t)
end

local function Nm(abilityId)
    if not abilityId then return "?" end
    local ok, n = pcall(GetAbilityName, abilityId)
    if ok and n and n ~= "" then return string.sub(n, 1, 18) end
    return "?"
end

-- EVENT_COMBAT_EVENT, source = player (light/heavy hit, kill)
local function OnSrc(_, result, isError, abilityName, _, slotType, sourceName, sourceType,
                     targetName, targetType, hitValue, powerType, damageType, _, sUid, tUid, abilityId)
    if isError then return end
    local c = S.c
    c.src = c.src + 1
    local rt = S.resSrc
    rt[result] = (rt[result] or 0) + 1              -- classification counter (cheap)
    if COMBAT_UNIT_TYPE_PLAYER ~= nil and targetType == COMBAT_UNIT_TYPE_PLAYER then c.srcToSelf = c.srcToSelf + 1 end
    local changed = false
    if result == ACTION_RESULT_KILLING_BLOW then
        c.kill = c.kill + 1
        changed = true
    elseif result == ACTION_RESULT_DAMAGE or result == ACTION_RESULT_CRITICAL_DAMAGE then
        if ACTION_SLOT_TYPE_LIGHT_ATTACK ~= nil and slotType == ACTION_SLOT_TYPE_LIGHT_ATTACK then
            c.light = c.light + 1
            changed = true
        elseif ACTION_SLOT_TYPE_HEAVY_ATTACK ~= nil and slotType == ACTION_SLOT_TYPE_HEAVY_ATTACK then
            c.heavy = c.heavy + 1
            changed = true
        end
    end
    if changed then
        S.last.srcLine = string.format("id=%s %s result=%s slotType=%s tgtType=%s",
            tostring(abilityId), Nm(abilityId), ResName(result), SlotTypeName(slotType), tostring(targetType))
    end
    if changed then Dirty() else DirtySlow() end
end

-- EVENT_COMBAT_EVENT, target = player (direct / DoT / shielded)
local function OnTgt(_, result, isError, abilityName, _, slotType, sourceName, sourceType,
                     targetName, targetType, hitValue, powerType, damageType, _, sUid, tUid, abilityId)
    if isError then return end
    local c = S.c
    c.tgt = c.tgt + 1
    local rt = S.resTgt
    rt[result] = (rt[result] or 0) + 1              -- classification counter (cheap)
    local fromSelf = (COMBAT_UNIT_TYPE_PLAYER ~= nil) and (sourceType == COMBAT_UNIT_TYPE_PLAYER)
    if fromSelf then c.tgtFromSelf = c.tgtFromSelf + 1 end
    local counted = true
    if result == ACTION_RESULT_DAMAGE or result == ACTION_RESULT_CRITICAL_DAMAGE then
        c.hitDirect = c.hitDirect + 1
    elseif result == ACTION_RESULT_DOT_TICK or result == ACTION_RESULT_DOT_TICK_CRITICAL then
        c.hitDot = c.hitDot + 1
    elseif ACTION_RESULT_DAMAGE_SHIELDED ~= nil and result == ACTION_RESULT_DAMAGE_SHIELDED then
        c.hitShield = c.hitShield + 1
    else
        c.hitOther = c.hitOther + 1
        counted = false
    end
    if counted then
        if fromSelf then c.hitFromSelf = c.hitFromSelf + 1 else c.hitFromOther = c.hitFromOther + 1 end
        S.last.tgtLine = string.format("id=%s %s result=%s value=%s dmgType=%s srcType=%s%s",
            tostring(abilityId), Nm(abilityId), ResName(result), tostring(hitValue), tostring(damageType),
            tostring(sourceType), fromSelf and "(SELF)" or "")
    end
    if counted then Dirty() else DirtySlow() end
end

-- EVENT_ACTION_SLOT_ABILITY_USED (skill / ultimate)
local function BoundId(slotNum)
    local ok, id = pcall(GetSlotBoundId, slotNum)
    if ok and id and id ~= 0 then S.api.boundIdForm = "1arg" return id end
    if GetActiveHotbarCategory then
        local ok2, id2 = pcall(function() return GetSlotBoundId(slotNum, GetActiveHotbarCategory()) end)
        if ok2 and id2 and id2 ~= 0 then S.api.boundIdForm = "2arg" return id2 end
    end
    if not S.api.boundIdForm then S.api.boundIdForm = "none" end
    return nil
end

-- Slot layout assumed from the v0.1.0 PS5 run: 1/2 = weapon attacks (light/heavy input, UNCONFIRMED),
-- 3-7 = skills, ULT candidate = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1 (UNCONFIRMED until a real ULT cast is checked).
local SKILL_FIRST, SKILL_LAST = 3, 7
local ULT_CAND = (ACTION_BAR_ULTIMATE_SLOT_INDEX ~= nil) and (ACTION_BAR_ULTIMATE_SLOT_INDEX + 1) or nil

local function SlotCost(slotNum)
    if type(GetSlotAbilityCost) ~= "function" then S.api.GetSlotAbilityCost = "N" return "NA" end
    local ok, cost, mech = pcall(GetSlotAbilityCost, slotNum)
    if not ok then S.api.GetSlotAbilityCost = "ERR" return "ERR" end
    S.api.GetSlotAbilityCost = "Y"
    return tostring(cost) .. (mech ~= nil and ("/m" .. tostring(mech)) or "")
end

-- Independent evidence for "is this ability an ultimate" (API existence/meaning UNVERIFIED on PS5)
local function UltApi(abilityId)
    if abilityId == nil then return "NA" end
    if type(IsAbilityUltimate) ~= "function" then S.api.IsAbilityUltimate = "N" return "NA" end
    local ok, v = pcall(IsAbilityUltimate, abilityId)
    if not ok then S.api.IsAbilityUltimate = "ERR" return "ERR" end
    S.api.IsAbilityUltimate = "Y"
    return v and "Y" or "N"
end

local function OnSlot(_, slotNum)
    local c = S.c
    c.slot = c.slot + 1
    S.slotCnt[slotNum] = (S.slotCnt[slotNum] or 0) + 1
    if slotNum == 1 then c.s1 = c.s1 + 1; DirtySlow() return end         -- weapon attack input (separate counter)
    if slotNum == 2 then c.s2 = c.s2 + 1; DirtySlow() return end
    local isUlt = (ULT_CAND ~= nil) and (slotNum == ULT_CAND)
    if isUlt then
        c.ultCand = c.ultCand + 1
    elseif slotNum ~= nil and slotNum >= SKILL_FIRST and slotNum <= SKILL_LAST then
        c.skill = c.skill + 1
    else
        c.slotOther = c.slotOther + 1
    end
    local id = BoundId(slotNum)
    local cost = SlotCost(slotNum)
    S.slotCost[slotNum] = cost
    local line = string.format("slot=%s ult-cand=%s boundId=%s %s cost=%s IsAbilityUltimate=%s",
        tostring(slotNum), isUlt and "Y" or "N", tostring(id), Nm(id), cost, UltApi(id))
    S.last.slotLine = line
    if isUlt then S.last.ultLine = line end
    Dirty()
end

local function RegisterCombat(name, nsKey, event, cb, filterConst, filterVal)
    if event == nil then S.reg[nsKey] = "not registered: event const nil" return end
    if filterConst ~= nil and filterVal == nil then S.reg[nsKey] = "not registered: filter value nil" return end
    if filterConst == nil and nsKey ~= "slot" then
        -- never register EVENT_COMBAT_EVENT unfiltered (Cyrodiil event volume)
        S.reg[nsKey] = "not registered: filter const missing" return
    end
    local ok, e = pcall(function() EVENT_MANAGER:RegisterForEvent(name, event, cb) end)
    if not ok then S.reg[nsKey] = "register ERR" Err("Register " .. nsKey, e) return end
    if filterConst ~= nil then
        local ok2, r = pcall(function() return EVENT_MANAGER:AddFilterForEvent(name, event, filterConst, filterVal) end)
        if not ok2 then S.reg[nsKey] = "registered, filter ERR" Err("AddFilter " .. nsKey, r) return end
        S.reg[nsKey] = "registered+filter(ret=" .. tostring(r) .. ")"
    else
        S.reg[nsKey] = "registered"
    end
end

local function RegisterAllEvents()
    BuildResultNames()
    RegisterCombat(ADDON .. "_Src", "src", EVENT_COMBAT_EVENT, OnSrc,
        REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    RegisterCombat(ADDON .. "_Tgt", "tgt", EVENT_COMBAT_EVENT, OnTgt,
        REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    RegisterCombat(ADDON .. "_Slot", "slot", EVENT_ACTION_SLOT_ABILITY_USED, OnSlot, nil, nil)
end

------------------------------------------------------------------
-- Screen text (rebuilt only when something changed)
------------------------------------------------------------------
local function F(v) if v == nil then return "-" end return tostring(v) end

local function SlotLine()
    local t = {}
    for n = 1, 12 do
        if S.slotCnt[n] then t[#t + 1] = "s" .. n .. "=" .. S.slotCnt[n] end
    end
    if #t == 0 then return "-" end
    return table.concat(t, " ")
end

local function TopLine(t, n)
    local arr = {}
    for code, cnt in pairs(t) do arr[#arr + 1] = { code, cnt } end
    table.sort(arr, function(a, b) if a[2] == b[2] then return a[1] < b[1] end return a[2] > b[2] end)
    local parts = {}
    for i = 1, math.min(n, #arr) do
        parts[#parts + 1] = string.sub(ResName(arr[i][1]), 1, 18) .. "=" .. arr[i][2]
    end
    if #arr > n then parts[#parts + 1] = "(+" .. (#arr - n) .. " more codes)" end
    if #parts == 0 then return "-" end
    return table.concat(parts, "  ")
end

local function ClassLine(t)
    local g = { dmg = 0, heal = 0, effect = 0, death = 0, other = 0, unknown = 0 }
    for code, cnt in pairs(t) do local k = ClassOf(code); g[k] = g[k] + cnt end
    return string.format("dmg=%d heal=%d effect=%d death=%d other=%d unknown(no const)=%d",
        g.dmg, g.heal, g.effect, g.death, g.other, g.unknown)
end

local function ApiLine(names)
    local t = {}
    for _, n in ipairs(names) do t[#t + 1] = n .. "=" .. (S.api[n] or "-") end
    return table.concat(t, " ")
end

Refresh = function()
    dirty = false
    if not label then return end
    local L = {}
    local c = S.c
    L[#L + 1] = "CombatMascotDiag v" .. VERSION .. "   (PS5 UNVERIFIED until you confirm)   seq: " .. S.seq
    L[#L + 1] = "API: " .. ApiLine({ "CreateTimeline", "InsertAnimation(ANIMATION_TEXTURE)", "SetImageData", "SetFramerate", "SetDuration" })
    L[#L + 1] = "API: " .. ApiLine({ "SetPlaybackType(ONE_SHOT)", "SetPlaybackType(LOOP)", "PlayFromStart", "Stop", "IsPlaying", "SetHandler(OnStop)" })
    L[#L + 1] = "API: IsTextureLoaded=" .. F(S.api.IsTextureLoaded) .. " OnTextureLoaded(set)=" .. F(S.api.OnTextureLoaded) ..
                " GetTextureFileDimensions=" .. F(S.api.GetTextureFileDimensions) .. " boundIdForm=" .. F(S.api.boundIdForm) ..
                " GetSlotAbilityCost=" .. F(S.api.GetSlotAbilityCost) .. " IsAbilityUltimate=" .. F(S.api.IsAbilityUltimate) .. " resultNames=" .. F(S.api.resultNames)
    L[#L + 1] = "[DDS LOAD]  1s / 2s / 3s  (Y=loaded N=not NA=no function)  cb=OnTextureLoaded ms  dim=file size"
    for _, k in ipairs(ORDER) do
        local ld = S.load[k] or { "-", "-", "-" }
        L[#L + 1] = string.format("  %s: %s / %s / %s   cb=%s  dim=%s", SHEETS[k].label, ld[1], ld[2], ld[3], F(ld.cbMs), F(ld.dim))
    end
    L[#L + 1] = "  (M must be N: it is the deliberately missing file)"
    L[#L + 1] = "[PLAY]  fps=" .. FPS .. "  expected: A 333ms, B/C 667ms per cycle"
    for _, row in ipairs(TESTS) do
        local s
        if not row.loop then
            s = string.format("  %s  exp=%s stop=%s playing@+150=%s  %s", row.id, F(row.exp), F(row.stopMs), F(row.playingAfter), F(row.state))
        else
            s = string.format("  %s  hide=%s playing@hide=%s probe@%s=%s  %s", row.id, F(row.hideActual),
                F(row.playingAtHide), F(row.probeAt), F(row.probe), F(row.state))
        end
        L[#L + 1] = s
    end
    L[#L + 1] = string.format("[INTERRUPT]  I1 stale timer ignored: %s   I2 lower/equal discarded: %s   I3 ends idle: %s   => %s",
        S.inter.i1, S.inter.i2, S.inter.i3, S.inter.all)
    L[#L + 1] = string.format("   token=%d stale=%d rejected=%d", ctl.token, ctl.stale, ctl.rejected)
    L[#L + 1] = string.format("[EVENTS]  register: src=%s | tgt=%s | slot=%s", S.reg.src, S.reg.tgt, S.reg.slot)
    L[#L + 1] = string.format("  passed filter: src=%d tgt=%d slot=%d  total=%d", c.src, c.tgt, c.slot, c.src + c.tgt + c.slot)
    L[#L + 1] = string.format("  hit-light=%d hit-heavy=%d kill=%d   skill(s3-7)=%d   ult-cand(s%s)=%d  [ULT UNCONFIRMED]",
        c.light, c.heavy, c.kill, c.skill, F(ULT_CAND), c.ultCand)
    L[#L + 1] = string.format("  hit taken: direct=%d dot=%d shielded=%d  non-hit results=%d   source: self=%d other=%d",
        c.hitDirect, c.hitDot, c.hitShield, c.hitOther, c.hitFromSelf, c.hitFromOther)
    L[#L + 1] = string.format("  overlap: src-events with target=player %d | tgt-events with source=player %d   (both PLAYER type = self events)",
        c.srcToSelf, c.tgtFromSelf)
    L[#L + 1] = "  last light/heavy/kill: " .. S.last.srcLine
    L[#L + 1] = "  last hit taken:        " .. S.last.tgtLine
    L[#L + 1] = string.format("[SLOTS]  s1(weapon input)=%d  s2(weapon input)=%d   other=%d   (separate from hit counts)", c.s1, c.s2, c.slotOther)
    L[#L + 1] = string.format("  s3=%d s4=%d s5=%d s6=%d s7=%d  s8=%d  | ULT const=%s -> its own slot count=%s",
        S.slotCnt[3] or 0, S.slotCnt[4] or 0, S.slotCnt[5] or 0, S.slotCnt[6] or 0, S.slotCnt[7] or 0, S.slotCnt[8] or 0,
        F(ACTION_BAR_ULTIMATE_SLOT_INDEX), F(ACTION_BAR_ULTIMATE_SLOT_INDEX and S.slotCnt[ACTION_BAR_ULTIMATE_SLOT_INDEX] or nil))
    L[#L + 1] = string.format("  cost(last use): s3=%s s4=%s s5=%s s6=%s s7=%s s8=%s   (1st return of GetSlotAbilityCost; unit unverified)",
        F(S.slotCost[3]), F(S.slotCost[4]), F(S.slotCost[5]), F(S.slotCost[6]), F(S.slotCost[7]), F(S.slotCost[8]))
    L[#L + 1] = "  last slot used (3+): " .. S.last.slotLine
    L[#L + 1] = "  last ult-cand:       " .. S.last.ultLine
    L[#L + 1] = "[RESULT src] " .. TopLine(S.resSrc, 5)
    L[#L + 1] = "   class(by const name, heuristic): " .. ClassLine(S.resSrc)
    L[#L + 1] = "[RESULT tgt] " .. TopLine(S.resTgt, 5)
    L[#L + 1] = "   class(by const name, heuristic): " .. ClassLine(S.resTgt)
    if S.err then L[#L + 1] = "ERR(" .. S.errCount .. "): " .. S.err end
    pcall(function() label:SetText(table.concat(L, "\n")) end)
end

------------------------------------------------------------------
-- Start-up sequence (once per session, no input needed)
------------------------------------------------------------------
local function StartLoadTest()
    S.seq = "DDS load test"
    for _, k in ipairs(ORDER) do
        local sh = SHEETS[k]
        S.load[k] = { "-", "-", "-" }
        if sh.ctrl then
            sh.loadStart = Now()
            Probe("SetTexture", function() sh.ctrl:SetTexture(PATH .. sh.file) end)
            StaticFirstCell(sh)
            pcall(function() sh.ctrl:SetHidden(false) end)
            if type(sh.ctrl.IsTextureLoaded) == "function" then S.api.IsTextureLoaded = "Y" else S.api.IsTextureLoaded = "N" end
            local okH, eH = pcall(function()
                sh.ctrl:SetHandler("OnTextureLoaded", function()
                    local ld = S.load[k]
                    if ld and not ld.cbMs then ld.cbMs = Now() - sh.loadStart end
                    Dirty()
                end)
            end)
            if okH then
                if S.api["OnTextureLoaded"] ~= "ERR" then S.api["OnTextureLoaded"] = "Y" end
            else
                S.api["OnTextureLoaded"] = "ERR"
                Err("SetHandler(OnTextureLoaded)", eH)
            end
        end
    end
    for i = 1, 3 do
        zo_callLater(function()
            for _, k in ipairs(ORDER) do
                local sh = SHEETS[k]
                S.load[k][i] = IsLoaded(sh)
                if i == 3 and sh.ctrl then
                    if type(sh.ctrl.GetTextureFileDimensions) == "function" then
                        local ok, w, h = pcall(sh.ctrl.GetTextureFileDimensions, sh.ctrl)
                        if ok then
                            S.api.GetTextureFileDimensions = "Y"
                            S.load[k].dim = tostring(w) .. "x" .. tostring(h)
                        else
                            S.api.GetTextureFileDimensions = "ERR"
                        end
                    else
                        S.api.GetTextureFileDimensions = "N"
                    end
                end
            end
            Dirty()
        end, i * 1000)
    end
end

local function RunAll()
    -- build timelines for the three real sheets
    BuildTimeline("A"); BuildTimeline("B"); BuildTimeline("C")
    StartLoadTest()
    zo_callLater(function()
        local i = 0
        local function nextTest()
            i = i + 1
            if i > #TESTS then
                RunInterrupt(function()
                    S.seq = "done (events keep counting)"
                    for _, k in ipairs({ "A", "B", "C" }) do
                        StaticFirstCell(SHEETS[k])
                        pcall(function() SHEETS[k].ctrl:SetHidden(false) end)
                    end
                    Dirty()
                end)
                return
            end
            S.seq = "play test " .. TESTS[i].id
            RunTest(TESTS[i], nextTest)
        end
        nextTest()
    end, 3400)
end

local function OnPlayerActivated()
    if started then return end
    started = true
    EVENT_MANAGER:UnregisterForEvent(ADDON .. "_Act", EVENT_PLAYER_ACTIVATED)
    if not BuildUI() then return end
    RegisterAllEvents()                -- events first, so combat during the tests is counted
    Refresh()
    zo_callLater(RunAll, 2000)         -- let the HUD settle
end

local function OnAddOnLoaded(_, name)
    if name ~= ADDON then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON .. "_Load", EVENT_ADD_ON_LOADED)
    EVENT_MANAGER:RegisterForEvent(ADDON .. "_Act", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end

EVENT_MANAGER:RegisterForEvent(ADDON .. "_Load", EVENT_ADD_ON_LOADED, OnAddOnLoaded)
