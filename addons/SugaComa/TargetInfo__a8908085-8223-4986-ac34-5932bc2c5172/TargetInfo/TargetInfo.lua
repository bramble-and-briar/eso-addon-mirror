-- TargetInfo.lua (Boss Bar + Reticle Boss Fallback + PvP Player Callouts w/ Sticky)
-- FIXES:
-- 1) Reticle boss fallback is DISABLED while compass boss bar is active (no double reporting).
-- 2) Blue header colour restored for boss-bar flow.
-- 3) PvP player callouts restored with optional STICKY + REACQUIRE to reduce reticle jitter losses.
-- NOTES:
-- - Boss Bar mode outputs bosses only (multi-boss pacing, sync colour).
-- - Reticle Boss mode is fallback for wandering bosses that do NOT trigger boss bar.
-- - PvP callouts: players only, alliance-coloured name, narration-safe formatting (no "/").

local ADDON_NAME = "TargetInfo"
local EM = EVENT_MANAGER

--------------------------------------------------------------
-- Output helpers (Chat / Alert / Center)
--------------------------------------------------------------
local function ChatMsg(text)
    if not text or text == "" then return end
    zo_callLater(function()
        if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
            CHAT_ROUTER:AddSystemMessage(tostring(text))
        else
            d(tostring(text))
        end
    end, 0)
end

local function CenterMsg(text, sound, colorCode)
    if not text or text == "" then return end
    local CSA = CENTER_SCREEN_ANNOUNCE
    zo_callLater(function()
        if CSA and CSA.CreateMessageParams and CSA.DisplayMessage then
            local params = CSA:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT, sound or SOUNDS.POSITIVE_CLICK)
            local colored = string.format("%s%s|r", colorCode or "|cFFFFFF", tostring(text))
            params:SetText(colored)
            CSA:DisplayMessage(params)
        else
            if ZO_Alert and UI_ALERT_CATEGORY_ALERT and SOUNDS then
                ZO_Alert(UI_ALERT_CATEGORY_ALERT, sound or SOUNDS.POSITIVE_CLICK, tostring(text))
            else
                d(tostring(text))
            end
        end
    end, 0)
end

local function Notify(msg, mode, colorCode, sound)
    -- mode: "chat" | "screen" | "both"
    mode = mode or "chat"
    if mode == "chat" or mode == "both" then
        ChatMsg(msg)
    end
    if mode == "screen" or mode == "both" then
        CenterMsg(msg, sound or SOUNDS.POSITIVE_CLICK, colorCode or "|cFFFFFF")
    end
end

local function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function NowMs()
    return (GetFrameTimeMilliseconds and GetFrameTimeMilliseconds())
        or (GetGameTimeMilliseconds and GetGameTimeMilliseconds())
        or 0
end

--------------------------------------------------------------
-- Custom message windows (screen replacements)
--------------------------------------------------------------
local MessageWindows = {}

local function BuildFont(size)
    return string.format("ZoFontGame|%d|soft-shadow-thick", size)
end

local function SetWindowBackground(w, level)
    if not w or not w.backdrop then return end
    local a = Clamp(level or 0, 0, 1)
    local shade = 1 - a
    w.backdrop:SetCenterColor(shade, shade, shade, a)
    w.backdrop:SetEdgeColor(0, 0, 0, a)
end

local function GetWindowSettings(key)
    if key == "pvp" then
        return
            TargetInfoSV.pvpWindowX or 0,
            TargetInfoSV.pvpWindowY or 0,
            TargetInfoSV.pvpWindowOpacity or 0.85,
            TargetInfoSV.pvpWindowFontSize or 28,
            TargetInfoSV.pvpWindowFadeMs or 6000,
            TargetInfoSV.pvpWindowMaxLines or 3
    end
    return
        TargetInfoSV.bossWindowX or 0,
        TargetInfoSV.bossWindowY or 0,
        TargetInfoSV.bossWindowOpacity or 0.85,
        TargetInfoSV.bossWindowFontSize or 28,
        TargetInfoSV.bossWindowFadeMs or 6000,
        TargetInfoSV.bossWindowMaxLines or 3
end

local function ApplyMessageWindowSettings(key)
    local w = MessageWindows[key]
    if not w then return end

    local x, y, opacity, fontSize, fadeMs, maxLines = GetWindowSettings(key)
    w.window:ClearAnchors()
    w.window:SetAnchor(CENTER, GuiRoot, CENTER, x, y)
    w.label:SetFont(BuildFont(fontSize))
    w.opacity = Clamp(opacity, 0, 1)
    w.fadeMs = math.max(0, fadeMs or 0)
    w.maxLines = math.max(1, maxLines or 1)
    SetWindowBackground(w, (#w.messages > 0) and w.opacity or 0)
    w.label:SetAlpha(#w.messages > 0 and 1 or 0)
    w.window:SetAlpha(1)
end

local function EnsureMessageWindow(key)
    if MessageWindows[key] then return end
    if not WINDOW_MANAGER then return end

    local winName = string.format("%s_%sWindow", ADDON_NAME, key)
    local win = WINDOW_MANAGER:CreateTopLevelWindow(winName)
    win:SetDimensions(800, 220)
    win:SetMouseEnabled(false)
    win:SetMovable(false)
    win:SetHidden(false)
    win:SetAlpha(0)

    local backdrop = WINDOW_MANAGER:CreateControl(winName .. "_BG", win, CT_BACKDROP)
    backdrop:SetAnchor(CENTER, win, CENTER, 0, 0)
    backdrop:SetDimensions(800, 220)
    backdrop:SetCenterColor(0, 0, 0, 0)
    backdrop:SetEdgeColor(0, 0, 0, 0)

    local label = WINDOW_MANAGER:CreateControl(winName .. "_Label", win, CT_LABEL)
    label:SetAnchor(CENTER, win, CENTER, 0, 0)
    label:SetDimensions(800, 220)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetText("")
    label:SetAlpha(0)

    MessageWindows[key] = {
        window = win,
        backdrop = backdrop,
        label = label,
        messages = {},
        previewText = nil,
        previewUntil = 0,
        opacity = 0.85,
        fadeMs = 6000,
        maxLines = 3,
    }
    ApplyMessageWindowSettings(key)
end

local function RefreshMessageWindow(key)
    local w = MessageWindows[key]
    if not w then return end

    local now = NowMs()
    local kept = {}
    local fadeMs = w.fadeMs or 0
    for _, msg in ipairs(w.messages) do
        if fadeMs <= 0 or (now - msg.time) <= fadeMs then
            table.insert(kept, msg)
        end
    end
    w.messages = kept

    local lines = {}
    for _, msg in ipairs(kept) do
        table.insert(lines, msg.text)
    end
    if #lines == 0 and w.previewUntil and now <= w.previewUntil and w.previewText then
        table.insert(lines, w.previewText)
    end
    if #lines == 0 then
        w.label:SetText("")
        SetWindowBackground(w, 0)
        w.label:SetAlpha(0)
        return
    end
    w.label:SetText(table.concat(lines, "\n"))
    SetWindowBackground(w, w.opacity or 1)
    w.label:SetAlpha(1)
end

local function ShowWindowPreview(key)
    EnsureMessageWindow(key)
    local w = MessageWindows[key]
    if not w then return end
    local label = (key == "pvp") and "PvP preview" or "Boss/Reticle preview"
    w.previewText = string.format("|cFFFFFF%s|r", label)
    local holdMs = math.max(3000, w.fadeMs or 0)
    w.previewUntil = NowMs() + holdMs
    RefreshMessageWindow(key)
end

local function AddMessageToWindow(key, text, colorCode, sound)
    EnsureMessageWindow(key)
    local w = MessageWindows[key]
    if not w then return end

    local colored = string.format("%s%s|r", colorCode or "|cFFFFFF", tostring(text))
    table.insert(w.messages, { text = colored, time = NowMs() })
    while #w.messages > (w.maxLines or 3) do
        table.remove(w.messages, 1)
    end

    if sound and sound ~= SOUNDS.NONE and PlaySound then
        PlaySound(sound)
    end
    RefreshMessageWindow(key)
end

local function NotifyCustom(msg, mode, colorCode, sound, windowKey)
    -- mode: "chat" | "screen" | "both"
    mode = mode or "chat"
    if mode == "chat" or mode == "both" then
        ChatMsg(msg)
    end
    if mode == "screen" or mode == "both" then
        if windowKey then
            AddMessageToWindow(windowKey, msg, colorCode, sound)
        else
            CenterMsg(msg, sound or SOUNDS.POSITIVE_CLICK, colorCode or "|cFFFFFF")
        end
    end
end

--------------------------------------------------------------
-- Formatting
--------------------------------------------------------------
local BLUE    = "|c66CCFF" -- your “system/header” blue
local WHITE   = "|cFFFFFF"
local GREY    = "|cAAAAAA"
local RED     = "|cFF3333"
local GREEN   = "|c00FF66"
local SOFTRED = "|cFF6666"

local C_BLUE  = "|c66CCFF"
local C_WHITE = "|cFFFFFF"
local C_GREEN = "|c00FF66"
local C_RED   = "|cFF3333"
local C_END   = "|r"

local function FormatCompactNumber(n)
    n = tonumber(n) or 0
    if n >= 1000000 then
        return string.format("%.1fm", n / 1000000)
    elseif n >= 1000 then
        return string.format("%.0fk", n / 1000)
    else
        return tostring(math.floor(n))
    end
end

--------------------------------------------------------------
-- Defaults
--------------------------------------------------------------
local defaults =
{
    enabled = true,

    ----------------------------------------------------------
    -- Boss Bar (Compass) Mode
    ----------------------------------------------------------
    bossStepPercent = 20, -- prints at 80/60/40/20 by default
    executePercent = 33,
    bossSyncTolerancePercent = 8, -- green if bosses are close enough to die together

    bossUpdateMode = "both", -- "execute" | "spread" | "both"
    bossBarNotifyMode = "chat", -- "chat" | "screen" | "both"
    executeNotifyMode = "both", -- "chat" | "screen" | "both"

    ----------------------------------------------------------
    -- Reticle Boss Fallback (wandering bosses / IC)
    -- IMPORTANT: runs ONLY when boss bar is NOT active.
    ----------------------------------------------------------
    reticleBossEnabled = true,
    reticleBossMinDifficulty = 3, -- confirmed sweet spot for patrol horrors etc.
    reticleBossMinHp = 0, -- skip reticle bosses under this max HP
    reticleBossStickyMs = 8000, -- base sticky; multiplied by 3 internally
    reticleBossNotifyMode = "chat", -- "chat" | "screen" | "both"
    reticleBossStepPercent = 20, -- step updates while reticle boss is tracked

    ----------------------------------------------------------
    -- PvP Player Callouts (players only)
    ----------------------------------------------------------
    pvpPlayersEnabled = true,
    pvpPlayerHoldSeconds = 1.3,
    pvpPlayerCooldownMs = 1300,
    pvpPlayerMinDeltaPercent = 0, -- 0 = cooldown-only gating

    -- Sticky / Reacquire (helps reticle jitter in fights)
    pvpStickyMs = 1500, -- keep last player “locked” for this long after losing reticle
    pvpReacquireWindowMs = 180000, -- if reacquired within 3 minutes, treat as same target memory

    pvpPlayerNotifyMode = "chat", -- "chat" | "screen" | "both"

    ----------------------------------------------------------
    -- Custom Windows (screen replacements)
    ----------------------------------------------------------
    bossWindowX = 0,
    bossWindowY = 0,
    bossWindowOpacity = 0.85,
    bossWindowFontSize = 28,
    bossWindowFadeMs = 6000,
    bossWindowMaxLines = 3,

    pvpWindowX = 0,
    pvpWindowY = 0,
    pvpWindowOpacity = 0.85,
    pvpWindowFontSize = 28,
    pvpWindowFadeMs = 6000,
    pvpWindowMaxLines = 3,
}

--------------------------------------------------------------
-- SavedVars (RESET: new name + single init + merge + repair)
--------------------------------------------------------------
local SV_NAME    = "TargetInfoSV2"  -- NEW name forces fresh saves for everyone
local SV_VERSION = 1                -- start at 1 for the new SV file

TargetInfoSV = TargetInfoSV or {}

local function InitSavedVars()
    if not (ZO_SavedVars and ZO_SavedVars.NewAccountWide) then
        -- Fallback: just ensure defaults exist
        TargetInfoSV = TargetInfoSV or {}
        for k, v in pairs(defaults) do
            if TargetInfoSV[k] == nil then
                TargetInfoSV[k] = v
            end
        end
        return
    end

    local sv = ZO_SavedVars:NewAccountWide(SV_NAME, SV_VERSION, nil, defaults)

    -- Merge defaults: NEW keys appear even if you forget to bump later
    for k, v in pairs(defaults) do
        if sv[k] == nil then
            sv[k] = v
        end
    end

    -- Type repair
    local function RepairNumber(key)
        if type(sv[key]) ~= "number" then sv[key] = defaults[key] end
    end
    local function RepairBool(key)
        if type(sv[key]) ~= "boolean" then sv[key] = defaults[key] end
    end
    local function RepairString(key)
        if type(sv[key]) ~= "string" then sv[key] = defaults[key] end
    end

    RepairBool("enabled")
    RepairNumber("bossStepPercent")
    RepairNumber("executePercent")
    RepairNumber("bossSyncTolerancePercent")
    RepairString("bossUpdateMode")
    RepairString("bossBarNotifyMode")
    RepairString("executeNotifyMode")

    RepairBool("reticleBossEnabled")
    RepairNumber("reticleBossMinDifficulty")
    RepairNumber("reticleBossMinHp")
    RepairNumber("reticleBossStickyMs")
    RepairString("reticleBossNotifyMode")
    RepairNumber("reticleBossStepPercent")

    RepairBool("pvpPlayersEnabled")
    RepairNumber("pvpPlayerHoldSeconds")
    RepairNumber("pvpPlayerCooldownMs")
    RepairNumber("pvpPlayerMinDeltaPercent")
    RepairNumber("pvpStickyMs")
    RepairNumber("pvpReacquireWindowMs")
    RepairString("pvpPlayerNotifyMode")

    RepairNumber("bossWindowX")
    RepairNumber("bossWindowY")
    RepairNumber("bossWindowOpacity")
    RepairNumber("bossWindowFontSize")
    RepairNumber("bossWindowFadeMs")
    RepairNumber("bossWindowMaxLines")

    RepairNumber("pvpWindowX")
    RepairNumber("pvpWindowY")
    RepairNumber("pvpWindowOpacity")
    RepairNumber("pvpWindowFontSize")
    RepairNumber("pvpWindowFadeMs")
    RepairNumber("pvpWindowMaxLines")

    TargetInfoSV = sv
end


--------------------------------------------------------------
-- Helpers
--------------------------------------------------------------
local function IsInPvP()
    return (IsInAvAZone and IsInAvAZone())
        or (IsInImperialCity and IsInImperialCity())
        or (IsActiveWorldBattleground and IsActiveWorldBattleground())
        or false
end

local function GetHP(unitTag)
    local cur, maxV
    if COMBAT_MECHANIC_FLAGS_HEALTH ~= nil then
        cur, maxV = GetUnitPower(unitTag, COMBAT_MECHANIC_FLAGS_HEALTH)
        if cur and maxV and maxV > 0 then
            return cur, maxV, (cur / maxV) * 100
        end
    end
    if POWERTYPE_HEALTH ~= nil then
        cur, maxV = GetUnitPower(unitTag, POWERTYPE_HEALTH)
        if cur and maxV and maxV > 0 then
            return cur, maxV, (cur / maxV) * 100
        end
    end
    return 0, 0, 0
end

local function SafeName(unitTag, fallback)
    local n = GetUnitName(unitTag)
    if not n or n == "" then return fallback or "Unknown" end
    return n
end

-- Update 51 separates ESO UserID from platform Online ID. Display follows
-- ESO's preference; target identity must never depend on that preference.
local function ReadUnitName(getter, unitTag)
    if type(getter) ~= "function" then return nil end
    local name = getter(unitTag)
    if type(name) == "string" and name ~= "" then return name end
    return nil
end

local function SafePlayerName(unitTag)
    local preferred = ReadUnitName(function(tag)
        if type(ZO_GetPrimaryPlayerNameFromUnitTag) == "function" then
            return ZO_GetPrimaryPlayerNameFromUnitTag(tag, true)
        end
    end, unitTag)
    return preferred
        or ReadUnitName(GetUnitPlatformDisplayName, unitTag)
        or ReadUnitName(GetUnitDisplayName, unitTag)
        or SafeName(unitTag, "Player")
end

local function SafeUniqueId(unitTag)
    -- Retain optional legacy support, but GetUnitUniqueId is not documented
    -- in API 101051. Never use an Online ID as if it were an ESO UserID.
    if type(GetUnitUniqueId) == "function" then
        local id = GetUnitUniqueId(unitTag)
        if id and id ~= 0 then return "unit:" .. tostring(id) end
    end
    local characterName = ReadUnitName(GetUnitName, unitTag)
    if IsUnitPlayer and IsUnitPlayer(unitTag) then
        local account = ReadUnitName(GetUnitDisplayName, unitTag)
        local kind = "eso:"
        if not account then
            account = ReadUnitName(GetUnitPlatformDisplayName, unitTag)
            kind = "platform:"
        end
        if account then
            -- Length prefix prevents ambiguous concatenations; retain the
            -- complete UserID, including any numeric discriminator.
            return kind .. #account .. ":" .. account .. ":" .. (characterName or "")
        end
        if characterName then return "character:" .. characterName end
        return nil
    end
    return characterName or "Unknown"
end

local function IsHostileAttackable(unitTag)
    if not DoesUnitExist(unitTag) or IsUnitDead(unitTag) then return false end
    if GetUnitReaction(unitTag) ~= UNIT_REACTION_HOSTILE then return false end
    if IsUnitAttackable and not IsUnitAttackable(unitTag) then return false end
    return true
end

--------------------------------------------------------------
-- Boss Bar active detection
--------------------------------------------------------------
local function BossBar_IsActive()
    local COMPASS = COMPASS_FRAME
    if not COMPASS then return false end
    if COMPASS.IsBossBarActive then
        return COMPASS:IsBossBarActive()
    end
    if COMPASS.GetBossBarActive then
        return COMPASS:GetBossBarActive()
    end
    if COMPASS.bossBar and COMPASS.bossBar.IsHidden then
        return not COMPASS.bossBar:IsHidden()
    end
    return false
end

--------------------------------------------------------------
-- PvP Player Styling (restored)
--------------------------------------------------------------
local function AllianceColorCode(alliance)
    if alliance == ALLIANCE_ALDMERI_DOMINION or alliance == 1 then
        return "|cFFD200" -- AD
    elseif alliance == ALLIANCE_EBONHEART_PACT or alliance == 2 then
        return "|cCC3333" -- EP
    elseif alliance == ALLIANCE_DAGGERFALL_COVENANT or alliance == 3 then
        return "|c3366FF" -- DC
    end
    return WHITE
end

local PvP =
{
    uid = nil,
    acquireMs = 0,
    lastSeenMs = 0,
    lastPrintMs = 0,
    lastPct = nil,
}

local function PvP_Reset()
    PvP.uid = nil
    PvP.acquireMs = 0
    PvP.lastSeenMs = 0
    PvP.lastPrintMs = 0
    PvP.lastPct = nil
end

local function PvPPlayerTick()
    if not TargetInfoSV.pvpPlayersEnabled then return end
    if not IsInPvP() then
        PvP_Reset()
        return
    end

    local now = NowMs()
    local tag = "reticleover"

    if not IsHostileAttackable(tag) or not (IsUnitPlayer and IsUnitPlayer(tag)) then
        -- Sticky: keep target “owned” briefly after losing reticle
        local sticky = TargetInfoSV.pvpStickyMs or 1500
        if PvP.uid and (now - (PvP.lastSeenMs or 0)) < sticky then
            return
        end
        PvP_Reset()
        return
    end

    local uid = SafeUniqueId(tag)
    PvP.lastSeenMs = now

    -- Reacquire behavior: if same uid, keep lastPct memory
    if PvP.uid ~= uid then
        PvP.uid = uid
        PvP.acquireMs = now
        PvP.lastPct = nil
        return
    end

    local holdSec = TargetInfoSV.pvpPlayerHoldSeconds or 1.3
    if (now - PvP.acquireMs) < (holdSec * 1000) then
        return
    end

    local cdMs = TargetInfoSV.pvpPlayerCooldownMs or 1300
    if (now - (PvP.lastPrintMs or 0)) < cdMs then
        return
    end

    local cur, maxV, pct = GetHP(tag)
    if maxV <= 0 then return end

    local minDelta = TargetInfoSV.pvpPlayerMinDeltaPercent or 0
    if minDelta > 0 and PvP.lastPct ~= nil then
        if math.abs(pct - PvP.lastPct) < minDelta then
            return
        end
    end

    local name = SafePlayerName(tag)
    local className = (GetUnitClass and GetUnitClass(tag)) or ""
    if className == "" then className = "Class" end

    local alliance = (GetUnitAlliance and GetUnitAlliance(tag)) or 0
    local aCol = AllianceColorCode(alliance)

    -- Narration-safe (no "/")
    -- Example: "SugaBane: Warden 42k health 50% 21k"
    local maxText = FormatCompactNumber(maxV)
    local curText = FormatCompactNumber(cur)
    local msg = string.format("%s%s|r: %s %s health %d%% %s",
        aCol, name, className, maxText, math.floor(pct + 0.5), curText)

    NotifyCustom(msg, TargetInfoSV.pvpPlayerNotifyMode, aCol, SOUNDS.NONE, "pvp")

    PvP.lastPrintMs = now
    PvP.lastPct = pct
end

--------------------------------------------------------------
-- Boss Bar Mode (multi-boss pacing, blue header)
--------------------------------------------------------------
local MAX_BOSSES = 8
local wasBossBarActive = false
local totalLastBucket = nil
local bossExecFired = {}

local function GetActiveBosses()
    local bosses = {}
    for i = 1, MAX_BOSSES do
        local tag = "boss" .. i
        local cur, maxV, pct = GetHP(tag)
        if maxV > 0 and pct > 0 then
            table.insert(bosses, {
                tag = tag,
                name = SafeName(tag, "Boss " .. i),
                cur = cur,
                maxV = maxV,
                pct = pct,
            })
        end
    end
    return bosses
end

local function ComputeTotalHP(bosses)
    local totalCur, totalMax = 0, 0
    for _, b in ipairs(bosses) do
        totalCur = totalCur + (b.cur or 0)
        totalMax = totalMax + (b.maxV or 0)
    end
    return totalCur, totalMax
end

local function BossesSynced(bosses, tolerancePct)
    if #bosses <= 1 then return true end
    tolerancePct = tolerancePct or 8

    local minP, maxP = 999, 0
    for _, b in ipairs(bosses) do
        minP = math.min(minP, b.pct or 0)
        maxP = math.max(maxP, b.pct or 0)
    end
    return (maxP - minP) <= tolerancePct
end

local function SortBossesByCurrentHPDesc(bosses)
    table.sort(bosses, function(a, b)
        return (a.cur or 0) > (b.cur or 0)
    end)
end

local function BossMode_OnStart(bosses, totalMax)
    totalLastBucket = 100
    bossExecFired = {}

    local count = #bosses
    local line1 = string.format("Boss fight. %d targets. Total %s HP.", count, FormatCompactNumber(totalMax))
    NotifyCustom(line1, TargetInfoSV.bossBarNotifyMode, BLUE, SOUNDS.DUEL_START, "boss")

    -- Initial boss list (max HP)
    if count > 0 then
        SortBossesByCurrentHPDesc(bosses)
        local parts = {}
        for _, b in ipairs(bosses) do
            table.insert(parts, string.format("%s%s|r %s HP", WHITE, b.name, FormatCompactNumber(b.maxV)))
        end
        NotifyCustom(table.concat(parts, " and "), TargetInfoSV.bossBarNotifyMode, BLUE, SOUNDS.NONE, "boss")
    end
end

local function BossMode_PrintUpdate(bosses, synced)
    if #bosses == 0 then return end
    SortBossesByCurrentHPDesc(bosses)

    local hpColor = synced and C_GREEN or C_RED
    local parts = {}

    for _, b in ipairs(bosses) do
        -- Blue name + colored HP number
        table.insert(parts, string.format("%s%s%s %s%s%s",
            C_BLUE, b.name, C_END,
            hpColor, FormatCompactNumber(b.cur), C_END
        ))
    end

    -- Example: Thickpelt 900k Longstride 700k
    local line = table.concat(parts, " ")
    NotifyCustom(line, TargetInfoSV.bossBarNotifyMode, synced and C_GREEN or C_RED, SOUNDS.NONE, "boss")
end

local function BossMode_PrintSpread(bosses)
    if #bosses < 2 then return end
    SortBossesByCurrentHPDesc(bosses)
    local high = bosses[1]
    local low = bosses[#bosses]
    local line = string.format("Spread: %s up. %s down.", high.name, low.name)
    NotifyCustom(line, TargetInfoSV.bossBarNotifyMode, BLUE, SOUNDS.NONE, "boss")
end

local function BossMode_CheckExecute(bosses)
    local exec = TargetInfoSV.executePercent or 33
    for _, b in ipairs(bosses) do
        if b.pct > 0 and b.pct <= exec and not bossExecFired[b.tag] then
            bossExecFired[b.tag] = true
            local msg = string.format("%s can be executed.", b.name)
            NotifyCustom(msg, TargetInfoSV.executeNotifyMode, SOFTRED, SOUNDS.DUEL_START, nil)
        elseif b.pct > exec and bossExecFired[b.tag] then
            bossExecFired[b.tag] = nil
        end
    end
end

local function BossModeTick()
    local active = BossBar_IsActive()

    if active and not wasBossBarActive then
        local bosses = GetActiveBosses()
        local _, totalMax = ComputeTotalHP(bosses)
        BossMode_OnStart(bosses, totalMax)
    elseif (not active) and wasBossBarActive then
        totalLastBucket = nil
        bossExecFired = {}
    end

    wasBossBarActive = active
    if not active then return end

    local bosses = GetActiveBosses()
    if #bosses == 0 then return end

    local totalCur, totalMax = ComputeTotalHP(bosses)
    if totalMax <= 0 then return end

    local step = Clamp(TargetInfoSV.bossStepPercent or 20, 5, 25)
    local totalPct = (totalCur / totalMax) * 100
    local bucket = math.floor(totalPct / step) * step

    if totalLastBucket == nil then
        totalLastBucket = bucket
        return
    end

    if bucket < totalLastBucket then
        totalLastBucket = bucket

        local synced = BossesSynced(bosses, TargetInfoSV.bossSyncTolerancePercent or 8)
        BossMode_PrintUpdate(bosses, synced)

        local mode = TargetInfoSV.bossUpdateMode or "both"
        if mode == "spread" or mode == "both" then
            BossMode_PrintSpread(bosses)
        end
        if mode == "execute" or mode == "both" then
            BossMode_CheckExecute(bosses)
        end
    end
end

--------------------------------------------------------------
-- Reticle Boss Fallback (ONLY when boss bar is NOT active)
--------------------------------------------------------------
local ReticleBoss =
{
    active = false,
    uid = nil,
    name = nil,
    lastSeenMs = 0,
    lastBucket = nil,
}

local function ReticleBoss_Reset()
    ReticleBoss.active = false
    ReticleBoss.uid = nil
    ReticleBoss.name = nil
    ReticleBoss.lastSeenMs = 0
    ReticleBoss.lastBucket = nil
end

local function ReticleBoss_IsValidTarget()
    if not TargetInfoSV.reticleBossEnabled then return false end

    local tag = "reticleover"
    if not IsHostileAttackable(tag) then return false end
    if IsUnitPlayer and IsUnitPlayer(tag) then return false end

    local nm = (GetUnitName(tag) or ""):lower()
    if nm == "blastbones" then return false end

    local diff = 0
    if type(GetUnitDifficulty) == "function" then
        diff = GetUnitDifficulty(tag) or 0
    end

    local minDiff = TargetInfoSV.reticleBossMinDifficulty or 3
    if diff < minDiff then return false end

    local _, maxV, pct = GetHP(tag)
    if not maxV or maxV <= 0 then return false end
    if pct <= 0 then return false end

    local minHp = TargetInfoSV.reticleBossMinHp or 0
    if minHp > 0 and maxV < minHp then return false end

    return true
end

local function ReticleBoss_PrintAcquire(name, cur)
    local line = string.format("Target acquired: %s %s HP.", name, FormatCompactNumber(cur))
    NotifyCustom(line, TargetInfoSV.reticleBossNotifyMode, BLUE, SOUNDS.NONE, "boss")
end

local function ReticleBoss_PrintLost(name)
    local line = string.format("Target lost: %s.", name)
    NotifyCustom(line, TargetInfoSV.reticleBossNotifyMode, GREY, SOUNDS.NONE, "boss")
end

local function ReticleBossTick()
    -- If the compass boss bar is active, reticle-boss detection is NOT needed
    -- and causes extra chatter. BossBar mode owns the fight.
    if BossBar_IsActive() then
        return
    end

    local now = NowMs()
    local tag = "reticleover"

    if ReticleBoss_IsValidTarget() then
        local uid = SafeUniqueId(tag)
        local name = SafeName(tag, "Target")
        local cur, _, pct = GetHP(tag)

        if not ReticleBoss.active or ReticleBoss.uid ~= uid then
            ReticleBoss.active = true
            ReticleBoss.uid = uid
            ReticleBoss.name = name
            ReticleBoss.lastBucket = nil
            ReticleBoss_PrintAcquire(name, cur)
        end

        ReticleBoss.lastSeenMs = now

        local step = Clamp(TargetInfoSV.reticleBossStepPercent or 20, 5, 25)
        local bucket = math.floor(pct / step) * step

        if ReticleBoss.lastBucket == nil then
            ReticleBoss.lastBucket = bucket
        elseif bucket < ReticleBoss.lastBucket then
            ReticleBoss.lastBucket = bucket
            ReticleBoss_PrintAcquire(name, cur)

            local exec = TargetInfoSV.executePercent or 33
            local mode = TargetInfoSV.bossUpdateMode or "both"
            if (mode == "execute" or mode == "both") and pct > 0 and pct <= exec then
                NotifyCustom(string.format("%s can be executed.", name), TargetInfoSV.executeNotifyMode, SOFTRED, SOUNDS.DUEL_START, nil)
            end
        end

        return
    end

    if ReticleBoss.active then
        local baseSticky = TargetInfoSV.reticleBossStickyMs or 8000
        local sticky = baseSticky * 3
        if (now - (ReticleBoss.lastSeenMs or 0)) > sticky then
            if ReticleBoss.name then ReticleBoss_PrintLost(ReticleBoss.name) end
            ReticleBoss_Reset()
        end
    end
end

--------------------------------------------------------------
-- Tick
--------------------------------------------------------------
local function Tick()
    if not TargetInfoSV.enabled then return end
    RefreshMessageWindow("boss")
    RefreshMessageWindow("pvp")
    BossModeTick()
    ReticleBossTick()
    PvPPlayerTick()
end

--------------------------------------------------------------
-- Settings menu (LibHarvensAddonSettings)
--------------------------------------------------------------
local function CreateSettings()
    if not LibHarvensAddonSettings then return end
    local LHAS = LibHarvensAddonSettings

    local settings = LHAS:AddAddon("TargetInfo", { allowDefaults = true, allowRefresh = true })
    if not settings then return end

    settings:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Enable TargetInfo",
        getFunction = function() return TargetInfoSV.enabled end,
        setFunction = function(v) TargetInfoSV.enabled = v end,
        default = true,
    })

    settings:AddSetting({ type = LHAS.ST_SECTION, label = "Boss Bar (Compass)" })

    settings:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Update Step",
        getFunction = function() return TargetInfoSV.bossStepPercent end,
        setFunction = function(v) TargetInfoSV.bossStepPercent = v; totalLastBucket = nil end,
        default = 20,
        min = 5, max = 25, step = 1,
        unit = "%",
        format = "%d",
    })

    settings:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Execute Threshold",
        getFunction = function() return TargetInfoSV.executePercent end,
        setFunction = function(v) TargetInfoSV.executePercent = v; bossExecFired = {} end,
        default = 33,
        min = 10, max = 50, step = 1,
        unit = "%",
        format = "%d",
    })

    settings:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Sync Tolerance",
        getFunction = function() return TargetInfoSV.bossSyncTolerancePercent end,
        setFunction = function(v) TargetInfoSV.bossSyncTolerancePercent = v end,
        default = 8,
        min = 2, max = 20, step = 1,
        unit = "%",
        format = "%d",
    })

    settings:AddSetting({
        type = LHAS.ST_DROPDOWN,
        label = "Boss Updates Include",
        items = {
            { name = "EXECUTE", data = "execute" },
            { name = "SPREAD",  data = "spread"  },
            { name = "BOTH",    data = "both"    },
        },
        getFunction = function()
            local m = TargetInfoSV.bossUpdateMode or "both"
            if m == "execute" then return "EXECUTE" end
            if m == "spread" then return "SPREAD" end
            return "BOTH"
        end,
        setFunction = function(_, _, item)
            TargetInfoSV.bossUpdateMode = item.data or "both"
        end,
        default = "BOTH",
    })

    settings:AddSetting({
        type = LHAS.ST_DROPDOWN,
        label = "Boss Lines Output",
        items = {
            { name = "CHAT",   data = "chat"   },
            { name = "SCREEN", data = "screen" },
            { name = "BOTH",   data = "both"   },
        },
        getFunction = function()
            local m = TargetInfoSV.bossBarNotifyMode or "chat"
            if m == "screen" then return "SCREEN" end
            if m == "both" then return "BOTH" end
            return "CHAT"
        end,
        setFunction = function(_, _, item)
            TargetInfoSV.bossBarNotifyMode = item.data or "chat"
        end,
        default = "CHAT",
    })

    settings:AddSetting({
        type = LHAS.ST_DROPDOWN,
        label = "Execute Output",
        items = {
            { name = "CHAT",   data = "chat"   },
            { name = "SCREEN", data = "screen" },
            { name = "BOTH",   data = "both"   },
        },
        getFunction = function()
            local m = TargetInfoSV.executeNotifyMode or "both"
            if m == "screen" then return "SCREEN" end
            if m == "chat" then return "CHAT" end
            return "BOTH"
        end,
        setFunction = function(_, _, item)
            TargetInfoSV.executeNotifyMode = item.data or "both"
        end,
        default = "BOTH",
    })

    settings:AddSetting({ type = LHAS.ST_SECTION, label = "Reticle Boss Fallback" })

    settings:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Enable Reticle Boss Fallback",
        tooltip = "Only used when no compass boss bar is active (wandering bosses).",
        getFunction = function() return TargetInfoSV.reticleBossEnabled end,
        setFunction = function(v) TargetInfoSV.reticleBossEnabled = v end,
        default = true,
    })

    settings:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Min Difficulty",
        tooltip = "Set to 3 for patrol horrors / big roaming bosses.",
        getFunction = function() return TargetInfoSV.reticleBossMinDifficulty end,
        setFunction = function(v) TargetInfoSV.reticleBossMinDifficulty = v end,
        default = 3,
        min = 0, max = 3, step = 1,
        format = "%d",
    })

    settings:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Fallback Update Step",
        getFunction = function() return TargetInfoSV.reticleBossStepPercent end,
        setFunction = function(v) TargetInfoSV.reticleBossStepPercent = v end,
        default = 20,
        min = 5, max = 25, step = 1,
        unit = "%",
        format = "%d",
    })

    settings:AddSetting({
        type = LHAS.ST_EDIT,
        label = "Min Boss HP (reticle)",
        tooltip = "If max HP is below this, reticle boss info is skipped.",
        getFunction = function()
            return tostring(TargetInfoSV.reticleBossMinHp or 0)
        end,
        setFunction = function(v)
            local n = tonumber(v) or 0
            if n < 0 then n = 0 end
            TargetInfoSV.reticleBossMinHp = n
        end,
        default = "0",
    })

    settings:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Sticky Time (base)",
        tooltip = "Internally multiplied for practical combat use.",
        getFunction = function() return TargetInfoSV.reticleBossStickyMs end,
        setFunction = function(v) TargetInfoSV.reticleBossStickyMs = v end,
        default = 8000,
        min = 1000, max = 15000, step = 500,
        unit = "ms",
        format = "%d",
    })

    settings:AddSetting({
        type = LHAS.ST_DROPDOWN,
        label = "Fallback Output",
        items = {
            { name = "CHAT",   data = "chat"   },
            { name = "SCREEN", data = "screen" },
            { name = "BOTH",   data = "both"   },
        },
        getFunction = function()
            local m = TargetInfoSV.reticleBossNotifyMode or "chat"
            if m == "screen" then return "SCREEN" end
            if m == "both" then return "BOTH" end
            return "CHAT"
        end,
        setFunction = function(_, _, item)
            TargetInfoSV.reticleBossNotifyMode = item.data or "chat"
        end,
        default = "CHAT",
    })

    settings:AddSetting({ type = LHAS.ST_SECTION, label = "PvP Player Callouts" })

    settings:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Enable PvP Player Callouts",
        getFunction = function() return TargetInfoSV.pvpPlayersEnabled end,
        setFunction = function(v) TargetInfoSV.pvpPlayersEnabled = v; PvP_Reset() end,
        default = true,
    })

    settings:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Hold Time",
        getFunction = function() return TargetInfoSV.pvpPlayerHoldSeconds end,
        setFunction = function(v) TargetInfoSV.pvpPlayerHoldSeconds = v; PvP_Reset() end,
        default = 1.3,
        min = 0.0, max = 3.0, step = 0.1,
        unit = "s",
        format = "%.1f",
    })

    settings:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Cooldown",
        getFunction = function() return TargetInfoSV.pvpPlayerCooldownMs end,
        setFunction = function(v) TargetInfoSV.pvpPlayerCooldownMs = v end,
        default = 1300,
        min = 300, max = 5000, step = 100,
        unit = "ms",
        format = "%d",
    })

    settings:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Sticky Time",
        tooltip = "Keeps the current player target briefly when reticle slips off.",
        getFunction = function() return TargetInfoSV.pvpStickyMs end,
        setFunction = function(v) TargetInfoSV.pvpStickyMs = v end,
        default = 1500,
        min = 0, max = 5000, step = 100,
        unit = "ms",
        format = "%d",
    })

    settings:AddSetting({
        type = LHAS.ST_DROPDOWN,
        label = "PvP Output",
        items = {
            { name = "CHAT",   data = "chat"   },
            { name = "SCREEN", data = "screen" },
            { name = "BOTH",   data = "both"   },
        },
        getFunction = function()
            local m = TargetInfoSV.pvpPlayerNotifyMode or "chat"
            if m == "screen" then return "SCREEN" end
            if m == "both" then return "BOTH" end
            return "CHAT"
        end,
        setFunction = function(_, _, item)
            TargetInfoSV.pvpPlayerNotifyMode = item.data or "chat"
        end,
        default = "CHAT",
    })

    settings:AddSetting({ type = LHAS.ST_SECTION, label = "Custom Message Windows" })

    settings:AddSetting({ type = LHAS.ST_SECTION, label = "Boss/Reticle Window" })

    settings:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Window X",
        tooltip = "0 = crosshair center. Negative left, positive right.",
        getFunction = function() return TargetInfoSV.bossWindowX end,
        setFunction = function(v) TargetInfoSV.bossWindowX = v; ApplyMessageWindowSettings("boss"); ShowWindowPreview("boss") end,
        default = 0,
        min = -1000, max = 1000, step = 10,
        unit = "px",
        format = "%d",
    })

    settings:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Window Y",
        tooltip = "0 = crosshair center. Negative up, positive down.",
        getFunction = function() return TargetInfoSV.bossWindowY end,
        setFunction = function(v) TargetInfoSV.bossWindowY = v; ApplyMessageWindowSettings("boss"); ShowWindowPreview("boss") end,
        default = 0,
        min = -1000, max = 1000, step = 10,
        unit = "px",
        format = "%d",
    })

    settings:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Opacity",
        tooltip = "0 = clear, 1 = black (darker background).",
        getFunction = function() return TargetInfoSV.bossWindowOpacity end,
        setFunction = function(v) TargetInfoSV.bossWindowOpacity = v; ApplyMessageWindowSettings("boss"); ShowWindowPreview("boss") end,
        default = 0.85,
        min = 0.0, max = 1.0, step = 0.05,
        format = "%.2f",
    })

    settings:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Font Size",
        getFunction = function() return TargetInfoSV.bossWindowFontSize end,
        setFunction = function(v) TargetInfoSV.bossWindowFontSize = v; ApplyMessageWindowSettings("boss"); ShowWindowPreview("boss") end,
        default = 28,
        min = 16, max = 48, step = 1,
        format = "%d",
    })

    settings:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Fade Duration",
        tooltip = "How long each line stays visible.",
        getFunction = function() return (TargetInfoSV.bossWindowFadeMs or 0) / 1000 end,
        setFunction = function(v)
            TargetInfoSV.bossWindowFadeMs = math.max(0, v * 1000)
            ApplyMessageWindowSettings("boss")
            ShowWindowPreview("boss")
        end,
        default = 6,
        min = 0, max = 20, step = 0.5,
        unit = "s",
        format = "%.1f",
    })

    settings:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Max Lines",
        tooltip = "Limits how many messages are shown at once.",
        getFunction = function() return TargetInfoSV.bossWindowMaxLines end,
        setFunction = function(v) TargetInfoSV.bossWindowMaxLines = v; ApplyMessageWindowSettings("boss"); ShowWindowPreview("boss") end,
        default = 3,
        min = 1, max = 5, step = 1,
        format = "%d",
    })

    settings:AddSetting({ type = LHAS.ST_SECTION, label = "PvP Window" })

    settings:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Window X",
        tooltip = "0 = crosshair center. Negative left, positive right.",
        getFunction = function() return TargetInfoSV.pvpWindowX end,
        setFunction = function(v) TargetInfoSV.pvpWindowX = v; ApplyMessageWindowSettings("pvp"); ShowWindowPreview("pvp") end,
        default = 0,
        min = -1000, max = 1000, step = 10,
        unit = "px",
        format = "%d",
    })

    settings:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Window Y",
        tooltip = "0 = crosshair center. Negative up, positive down.",
        getFunction = function() return TargetInfoSV.pvpWindowY end,
        setFunction = function(v) TargetInfoSV.pvpWindowY = v; ApplyMessageWindowSettings("pvp"); ShowWindowPreview("pvp") end,
        default = 0,
        min = -1000, max = 1000, step = 10,
        unit = "px",
        format = "%d",
    })

    settings:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Opacity",
        tooltip = "0 = clear, 1 = black (darker background).",
        getFunction = function() return TargetInfoSV.pvpWindowOpacity end,
        setFunction = function(v) TargetInfoSV.pvpWindowOpacity = v; ApplyMessageWindowSettings("pvp"); ShowWindowPreview("pvp") end,
        default = 0.85,
        min = 0.0, max = 1.0, step = 0.05,
        format = "%.2f",
    })

    settings:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Font Size",
        getFunction = function() return TargetInfoSV.pvpWindowFontSize end,
        setFunction = function(v) TargetInfoSV.pvpWindowFontSize = v; ApplyMessageWindowSettings("pvp"); ShowWindowPreview("pvp") end,
        default = 28,
        min = 16, max = 48, step = 1,
        format = "%d",
    })

    settings:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Fade Duration",
        tooltip = "How long each line stays visible.",
        getFunction = function() return (TargetInfoSV.pvpWindowFadeMs or 0) / 1000 end,
        setFunction = function(v)
            TargetInfoSV.pvpWindowFadeMs = math.max(0, v * 1000)
            ApplyMessageWindowSettings("pvp")
            ShowWindowPreview("pvp")
        end,
        default = 6,
        min = 0, max = 20, step = 0.5,
        unit = "s",
        format = "%.1f",
    })

    settings:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Max Lines",
        tooltip = "Limits how many messages are shown at once.",
        getFunction = function() return TargetInfoSV.pvpWindowMaxLines end,
        setFunction = function(v) TargetInfoSV.pvpWindowMaxLines = v; ApplyMessageWindowSettings("pvp"); ShowWindowPreview("pvp") end,
        default = 3,
        min = 1, max = 5, step = 1,
        format = "%d",
    })

    ----------------------------------------------------------
    -- Signature
    ----------------------------------------------------------
    settings:AddSetting({
        type = LHAS.ST_LABEL,
        label = "|cFFD700Built on tea, toast and ADHD – tested live on PS5.|r\n" ..
                "|cB427D3Su|c546D6Aga|c889764Co|cDA34CDma|r",
    })
end

--------------------------------------------------------------
-- Init
--------------------------------------------------------------
local INITIALIZED = false

local function Initialize()
    if INITIALIZED then return end
    INITIALIZED = true

    InitSavedVars()
    CreateSettings()
    EnsureMessageWindow("boss")
    EnsureMessageWindow("pvp")

    EM:UnregisterForUpdate(ADDON_NAME .. "_Tick")
    EM:RegisterForUpdate(ADDON_NAME .. "_Tick", 200, Tick)

    ChatMsg(BLUE .. "TargetInfo loaded.|r")
end

local function OnAddonLoaded(event, addonName)
    if addonName ~= ADDON_NAME then return end
    EM:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    Initialize()
end

EM:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
