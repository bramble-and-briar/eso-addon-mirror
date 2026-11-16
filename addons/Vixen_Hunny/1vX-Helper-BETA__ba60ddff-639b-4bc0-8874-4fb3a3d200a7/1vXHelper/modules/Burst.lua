-- 1vX Helper - Burst Monitor
-- Sums incoming damage inside a sliding window (default 1s). When the sum reaches the
-- user threshold a flashing red "KITE" warning shows for alertDuration (default 2s),
-- followed by a grace period (default 2s) during which the alert cannot retrigger.
--
-- CPU notes:
--  * One event registration per damage result type, filtered in the engine by
--    result + target = player + not error. The game never calls our Lua for heals,
--    buffs, outgoing damage, etc.
--  * Hits go in a fixed-size ring buffer (two number arrays): no tables are created
--    per hit, so nothing for the garbage collector to clean up in long fights.
--  * The timer only runs while there's damage in the window or an alert / grace is
--    active. Out of combat it falls back to a slow idle refresh (or stops entirely
--    when the meter is hidden).
--  * Max health is cached instead of being read on every hit.
--  * Labels are only re-written when their text actually changes.
--  * "Only in PvP zones" unregisters everything outside PvP instead of filtering per hit.
local addon = OneVXHelper
local B = {}
addon.Burst = B

local NS = "OneVXHelper_Burst"
local TICK_NAME = NS .. "Tick"
local HEALTH = COMBAT_MECHANIC_FLAGS_HEALTH or POWERTYPE_HEALTH
local IDLE_RATE_MS = 1000

local IDLE, ALERT, GRACE = 0, 1, 2

-- ring buffer --------------------------------------------------------------------
local CAP = 256
local hitT, hitV = {}, {}
local first, count, total = 1, 0, 0

-- state --------------------------------------------------------------------------
local state, alertEnd, graceEnd = IDLE, 0, 0
local registeredNs = {}
local registeredSig = nil
local tickRate = nil       -- current RegisterForUpdate interval (nil = not running)
local cachedThreshold = math.huge
local lastMeterText, lastStateText, lastBarBucket, lastAlertText

local alertWin, alertLabel
local meterWin, meterLabel, stateLabel, bar

local function C() return addon.sv.burst end

local function Short(n)
    if n == math.huge then return "?" end
    if n >= 1000 then return string.format("%.1fk", n / 1000) end
    return tostring(zo_round(n))
end

local function ResetWindow()
    first, count, total = 1, 0, 0
end

local function Push(t, v)
    if count == CAP then -- full: drop the oldest
        total = total - hitV[first]
        first = first % CAP + 1
        count = count - 1
    end
    local idx = (first + count - 1) % CAP + 1
    hitT[idx], hitV[idx] = t, v
    count = count + 1
    total = total + v
end

local function Prune(now)
    local cutoff = now - C().window * 1000
    while count > 0 and hitT[first] < cutoff do
        total = total - hitV[first]
        first = first % CAP + 1
        count = count - 1
    end
    if count == 0 then total = 0 end
end

local function RefreshThreshold()
    local c = C()
    if c.mode == "percent" then
        local _, maxHp = GetUnitPower("player", HEALTH)
        cachedThreshold = (maxHp and maxHp > 0) and (maxHp * c.pctThreshold / 100) or math.huge
    else
        cachedThreshold = c.absThreshold
    end
    return cachedThreshold
end

function B.GetThreshold()
    return cachedThreshold
end

---------------------------------------------------------------------------
-- Display
---------------------------------------------------------------------------
local lastFlashPhase
local function Flash(ctrl, t)
    local phase = math.floor(t * 6) % 2
    if phase ~= lastFlashPhase then
        lastFlashPhase = phase
        ctrl:SetAlpha(phase == 0 and 1 or 0.2)
    end
end

local function SetAlertText(text)
    if text ~= lastAlertText then
        lastAlertText = text
        alertLabel:SetText(text)
    end
end

local function ShowMode(mode, remaining)
    local c = C()
    if mode == "alert" then
        SetAlertText(c.alertText)
        alertLabel:SetColor(1, 0.1, 0.1, 1)
        lastFlashPhase = nil
        alertLabel:SetHandler("OnUpdate", Flash)
        alertLabel:SetHidden(false)
    elseif mode == "grace" and c.showGraceText then
        alertLabel:SetHandler("OnUpdate", nil)
        alertLabel:SetAlpha(0.9)
        SetAlertText(string.format("GRACE %.1fs", remaining or 0))
        alertLabel:SetColor(1, 0.75, 0.1, 1)
        alertLabel:SetHidden(false)
    elseif addon.unlocked then
        alertLabel:SetHandler("OnUpdate", nil)
        alertLabel:SetAlpha(1)
        SetAlertText(c.alertText)
        alertLabel:SetColor(1, 0.1, 0.1, 1)
        alertLabel:SetHidden(false)
    else
        alertLabel:SetHandler("OnUpdate", nil)
        alertLabel:SetHidden(true)
    end
end

local function CurrentMode()
    if state == ALERT then return "alert" end
    if state == GRACE then return "grace" end
    return "none"
end

local function UpdateMeter(now)
    if not meterWin.enabled or meterWin.tlw:IsHidden() then return end
    local threshold = cachedThreshold
    local ratio = (threshold > 0 and threshold ~= math.huge) and (total / threshold) or 0

    local text = "Burst " .. Short(total) .. " / " .. Short(threshold)
    if text ~= lastMeterText then
        lastMeterText = text
        meterLabel:SetText(text)
    end

    bar:SetValue(zo_clamp(ratio, 0, 1))
    local bucket = (ratio < 0.5 and 1) or (ratio < 1 and 2) or 3
    if bucket ~= lastBarBucket then
        lastBarBucket = bucket
        if bucket == 1 then bar:SetColor(0.2, 0.85, 0.3, 1)
        elseif bucket == 2 then bar:SetColor(1, 0.8, 0.1, 1)
        else bar:SetColor(1, 0.15, 0.15, 1) end
    end

    local stext
    if state == ALERT then
        stext = string.format("|cFF3333KITE %.1fs|r", math.max(0, (alertEnd - now) / 1000))
    elseif state == GRACE then
        stext = string.format("|cFFC020GRACE %.1fs|r", math.max(0, (graceEnd - now) / 1000))
    else
        stext = "|c40D060SAFE|r"
    end
    if stext ~= lastStateText then
        lastStateText = stext
        stateLabel:SetText(stext)
    end
end

---------------------------------------------------------------------------
-- Timer management
---------------------------------------------------------------------------
local Tick -- forward

local function SetTickRate(ms)
    if tickRate == ms then return end
    if tickRate then EVENT_MANAGER:UnregisterForUpdate(TICK_NAME) end
    tickRate = ms
    if ms then EVENT_MANAGER:RegisterForUpdate(TICK_NAME, ms, Tick) end
end

local function IsActive()
    return count > 0 or state ~= IDLE
end

-- fast while something is happening, slow (or off) when idle
local function UpdateTickRate()
    if IsActive() then
        SetTickRate(C().updateRate)
    elseif registeredSig and C().showMeter then
        SetTickRate(IDLE_RATE_MS)
    else
        SetTickRate(nil)
    end
end

---------------------------------------------------------------------------
-- State machine
---------------------------------------------------------------------------
local function StartAlert(now)
    local c = C()
    state = ALERT
    alertEnd = now + c.alertDuration * 1000
    ShowMode("alert")
    if c.playSound then
        local s = SOUNDS and SOUNDS[c.sound]
        if s then PlaySound(s) end
    end
end

Tick = function()
    local now = addon.Now()
    RefreshThreshold()
    Prune(now)
    if state == ALERT and now >= alertEnd then
        local grace = C().graceDuration
        if grace > 0 then
            state = GRACE
            graceEnd = now + grace * 1000
            ShowMode("grace", grace)
        else
            state = IDLE
            ShowMode("none")
        end
    elseif state == GRACE then
        if now >= graceEnd then
            state = IDLE
            ShowMode("none")
        elseif C().showGraceText then
            SetAlertText(string.format("GRACE %.1fs", (graceEnd - now) / 1000))
        end
    end
    UpdateMeter(now)
    UpdateTickRate()
end

local function OnCombatEvent(_, _, _, _, _, _, _, sourceType, _, _, hitValue, _, _, _, _, _, _, overflow)
    if sourceType == COMBAT_UNIT_TYPE_PLAYER then return end -- ignore self damage
    local amount = (hitValue or 0) + (overflow or 0)
    if amount <= 0 then return end

    local now = addon.Now()
    local wasActive = IsActive()
    Push(now, amount)
    Prune(now)

    if total >= cachedThreshold then
        if state == IDLE then
            StartAlert(now)
        elseif state == ALERT and C().extendOnRepeat then
            alertEnd = now + C().alertDuration * 1000
        end
    end
    if not wasActive then
        UpdateTickRate()
        UpdateMeter(now)
    end
end

local function OnDeathState()
    ResetWindow()
    state = IDLE
    ShowMode("none")
    UpdateTickRate()
end

---------------------------------------------------------------------------
-- Event registration
---------------------------------------------------------------------------
local function WantedResults()
    local c = C()
    local list = {}
    local function add(r) if r ~= nil then list[#list + 1] = r end end
    add(ACTION_RESULT_DAMAGE)
    add(ACTION_RESULT_CRITICAL_DAMAGE)
    if c.countDots then add(ACTION_RESULT_DOT_TICK); add(ACTION_RESULT_DOT_TICK_CRITICAL) end
    if c.countBlocked then add(ACTION_RESULT_BLOCKED_DAMAGE) end
    if c.countShielded then add(ACTION_RESULT_DAMAGE_SHIELDED) end
    return list
end

local function UnregisterAll()
    for _, ns in ipairs(registeredNs) do
        EVENT_MANAGER:UnregisterForEvent(ns, EVENT_COMBAT_EVENT)
    end
    registeredNs = {}
    if registeredSig then
        EVENT_MANAGER:UnregisterForEvent(NS .. "Dead", EVENT_PLAYER_DEAD)
        EVENT_MANAGER:UnregisterForEvent(NS .. "Alive", EVENT_PLAYER_ALIVE)
    end
    registeredSig = nil
end

local function RegisterAll(results, sig)
    for _, r in ipairs(results) do
        local ns = NS .. "_R" .. r
        EVENT_MANAGER:RegisterForEvent(ns, EVENT_COMBAT_EVENT, OnCombatEvent)
        EVENT_MANAGER:AddFilterForEvent(ns, EVENT_COMBAT_EVENT,
            REGISTER_FILTER_COMBAT_RESULT, r,
            REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER,
            REGISTER_FILTER_IS_ERROR, false)
        registeredNs[#registeredNs + 1] = ns
    end
    EVENT_MANAGER:RegisterForEvent(NS .. "Dead", EVENT_PLAYER_DEAD, OnDeathState)
    EVENT_MANAGER:RegisterForEvent(NS .. "Alive", EVENT_PLAYER_ALIVE, OnDeathState)
    registeredSig = sig
end

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------
function B.Test()
    if not C().enabled then addon.Print("Burst monitor is disabled.") return end
    state = IDLE
    StartAlert(addon.Now())
    if not registeredSig then
        -- outside PvP with "PvP only" on: still let the test play out
        SetTickRate(C().updateRate)
    else
        UpdateTickRate()
    end
end

function B.Apply()
    local c = C()
    addon.UI.SetEnabled(alertWin, c.enabled)
    addon.UI.SetEnabled(meterWin, c.enabled and c.showMeter)

    local active = c.enabled and (not c.pvpOnly or addon.InPvPZone())
    local results = active and WantedResults() or nil
    local sig = results and table.concat(results, ",") or nil

    if sig ~= registeredSig then
        UnregisterAll()
        if sig then RegisterAll(results, sig) end
        if not sig then
            ResetWindow()
            state = IDLE
        end
    end

    RefreshThreshold()
    lastMeterText, lastStateText, lastBarBucket, lastAlertText = nil, nil, nil, nil
    local now = addon.Now()
    ShowMode(CurrentMode(), math.max(0, (graceEnd - now) / 1000))
    alertLabel:SetFont(addon.UI.Font("BOLD_FONT", c.alertSize, "thick-outline"))
    UpdateMeter(now)
    UpdateTickRate()
end

function B.Init()
    -- Big flashing alert
    alertWin = addon.UI.CreateWindow("BurstAlert", 520, 90, 0, -220, { title = "Burst Alert" })
    alertLabel = addon.UI.Label("OneVXHelper_BurstAlertLabel", alertWin.content,
        addon.UI.Font("BOLD_FONT", C().alertSize, "thick-outline"), 1, 0.1, 0.1, 1)
    alertLabel:SetAnchorFill()
    alertLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    alertLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    alertLabel:SetHidden(true)
    alertWin.onPreview = function()
        ShowMode(CurrentMode(), math.max(0, (graceEnd - addon.Now()) / 1000))
    end

    -- Small live meter
    meterWin = addon.UI.CreateWindow("BurstMeter", 220, 42, 0, 140, { title = "Burst Meter" })
    local bgTex = WINDOW_MANAGER:CreateControl("OneVXHelper_BurstMeterBG", meterWin.content, CT_TEXTURE)
    bgTex:SetAnchorFill()
    bgTex:SetColor(0, 0, 0, 0.45)

    meterLabel = addon.UI.Label("OneVXHelper_BurstMeterLabel", meterWin.content,
        addon.UI.Font("MEDIUM_FONT", 15, "soft-shadow-thin"))
    meterLabel:SetAnchor(TOPLEFT, meterWin.content, TOPLEFT, 6, 3)

    stateLabel = addon.UI.Label("OneVXHelper_BurstMeterState", meterWin.content,
        addon.UI.Font("BOLD_FONT", 15, "soft-shadow-thin"))
    stateLabel:SetAnchor(TOPRIGHT, meterWin.content, TOPRIGHT, -6, 3)

    local barBG = WINDOW_MANAGER:CreateControl("OneVXHelper_BurstMeterBarBG", meterWin.content, CT_TEXTURE)
    barBG:SetAnchor(BOTTOMLEFT, meterWin.content, BOTTOMLEFT, 6, -5)
    barBG:SetAnchor(BOTTOMRIGHT, meterWin.content, BOTTOMRIGHT, -6, -5)
    barBG:SetHeight(10)
    barBG:SetColor(0.15, 0.15, 0.15, 0.9)

    bar = WINDOW_MANAGER:CreateControl("OneVXHelper_BurstMeterBar", meterWin.content, CT_STATUSBAR)
    bar:SetAnchorFill(barBG)
    bar:SetMinMax(0, 1)
    bar:SetValue(0)

    B.Apply()
end
