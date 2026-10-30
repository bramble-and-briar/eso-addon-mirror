-- TargetInfo.lua v1.2.5 (Boss/Player Callouts + Overland Encounter Difficulty)
-- Enemy information: percentage-drop health reports and once-per-fight execute alerts.
-- Overland difficulty uses the baseline with tougher-encounter overrides.
-- Internal ESO unit-tag/API names remain unchanged; settings use player-facing terms.

local ADDON_NAME = "TargetInfo"
local EM = EVENT_MANAGER
local MAX_BOSSES = 8

--------------------------------------------------------------
-- Output helpers (Chat / Alert / Center)
--------------------------------------------------------------
local function ChatMsg(text, stillValid, tag)
    if not text or text == "" then return end
    local message = "[" .. (tag or "Target Info") .. "] " .. tostring(text)
    zo_callLater(function()
        if stillValid and not stillValid() then return end
        if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
            CHAT_ROUTER:AddSystemMessage(message)
        else
            d(message)
        end
    end, 0)
end

local function CenterMsg(text, sound, colorCode, stillValid)
    if not text or text == "" then return end
    local CSA = CENTER_SCREEN_ANNOUNCE
    zo_callLater(function()
        if stillValid and not stillValid() then return end
        if CSA and CSA.CreateMessageParams and CSA.DisplayMessage then
            local params = CSA:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT, sound or SOUNDS.POSITIVE_CLICK)
            local colored = string.format("%s%s|r", colorCode or "|cFFFFFF", tostring(text))
            params:SetText(colored)
            CSA:DisplayMessage(params)
        else
            if ZO_Alert and UI_ALERT_CATEGORY_ALERT and SOUNDS then
                ZO_Alert(UI_ALERT_CATEGORY_ALERT, sound or SOUNDS.POSITIVE_CLICK, tostring(text))
            else
                ChatMsg(text, stillValid)
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
        if (not msg.stillValid or msg.stillValid()) and (fadeMs <= 0 or (now - msg.time) <= fadeMs) then
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
    local label = (key == "pvp") and "PvP preview" or "Enemy preview"
    w.previewText = string.format("|cFFFFFF%s|r", label)
    local holdMs = math.max(3000, w.fadeMs or 0)
    w.previewUntil = NowMs() + holdMs
    RefreshMessageWindow(key)
end

local function AddMessageToWindow(key, text, colorCode, sound, stillValid)
    EnsureMessageWindow(key)
    local w = MessageWindows[key]
    if not w then return end

    local colored = string.format("%s%s|r", colorCode or "|cFFFFFF", tostring(text))
    table.insert(w.messages, { text = colored, time = NowMs(), stillValid = stillValid })
    while #w.messages > (w.maxLines or 3) do
        table.remove(w.messages, 1)
    end

    if sound and sound ~= SOUNDS.NONE and PlaySound then
        PlaySound(sound)
    end
    RefreshMessageWindow(key)
end

local function NotifyCustom(msg, mode, colorCode, sound, windowKey, stillValid, chatText)
    -- mode: "chat" | "screen" | "both"
    mode = mode or "chat"
    if mode == "chat" or mode == "both" then
        ChatMsg(chatText or msg, stillValid)
    end
    if mode == "screen" or mode == "both" then
        if windowKey then
            AddMessageToWindow(windowKey, msg, colorCode, sound, stillValid)
        else
            CenterMsg(msg, sound or SOUNDS.POSITIVE_CLICK, colorCode or "|cFFFFFF", stillValid)
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
local NAME_COLOUR = "|c50D6C5"
local HEALTH_COLOUR = "|c8DBFFF"

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

    -- Encounter-based Challenge Difficulty (uses the current character).
    challengeDifficultyEnabled = false,
    challengeDifficultyNotify = true,
    challengeDifficultyElite = -1,
    challengeDifficultyBoss = -1,
    challengeDifficultyWorldEvent = -1,
    challengeDifficultyIdle = -1,

    ----------------------------------------------------------
    -- Boss Bar (Compass) Mode
    ----------------------------------------------------------
    bossStepPercent = 20, -- prints at 80/60/40/20 by default
    bossIdentification = "name",
    executePercent = 33,

    bossUpdateMode = "both", -- "off" | "execute" | "health" | "both"
    bossBarNotifyMode = "chat", -- "chat" | "screen" | "both"
    executeNotifyMode = "both", -- "chat" | "screen" | "both"

    ----------------------------------------------------------
    -- Reticle Boss Fallback (wandering bosses / IC)
    -- IMPORTANT: runs ONLY when boss bar is NOT active.
    ----------------------------------------------------------
    reticleBossEnabled = true,
    reticleBossMinDifficulty = 3, -- confirmed sweet spot for patrol horrors etc.
    reticleBossStickyMs = 8000, -- base sticky; multiplied by 3 internally

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

local function NormalizeInformationMode(value)
    if type(value) == "table" then value = value.data or value.value or value.name end
    local aliases = { ["OFF"] = "off", ["EXECUTE ONLY"] = "execute", ["EXECUTE"] = "execute",
        ["HEALTH ONLY"] = "health", ["HEALTH AND EXECUTE"] = "both", ["BOTH"] = "both", ["SPREAD"] = "health", spread = "health" }
    value = aliases[value] or value
    if value == "off" or value == "execute" or value == "health" or value == "both" then return value end
    return "execute"
end

local function NormalizeInformationOutput(value, fallback)
    if type(value) == "table" then value = value.data or value.value or value.name end
    if type(value) == "string" then value = string.lower(value) end
    if value == "chat" or value == "screen" or value == "both" then return value end
    return fallback or "chat"
end

local function EnemyHealthEnabled()
    local mode = NormalizeInformationMode(TargetInfoSV.bossUpdateMode)
    return mode == "health" or mode == "both"
end

local function EnemyExecuteEnabled()
    local mode = NormalizeInformationMode(TargetInfoSV.bossUpdateMode)
    return mode == "execute" or mode == "both"
end

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
    RepairBool("challengeDifficultyEnabled")
    RepairBool("challengeDifficultyNotify")
    for _, key in ipairs({ "challengeDifficultyElite", "challengeDifficultyBoss", "challengeDifficultyWorldEvent", "challengeDifficultyIdle" }) do
        local value = sv[key]
        if type(value) ~= "number" or value < -1 or value > 3 or value ~= math.floor(value) then sv[key] = -1 end
    end
    RepairNumber("bossStepPercent")
    sv.bossStepPercent = Clamp(sv.bossStepPercent, 10, 35)
    if sv.bossIdentification ~= "name" and sv.bossIdentification ~= "difficulty" and sv.bossIdentification ~= "both" then
        sv.bossIdentification = "name"
    end
    RepairNumber("executePercent")
    sv.bossUpdateMode = NormalizeInformationMode(sv.bossUpdateMode)
    sv.bossBarNotifyMode = NormalizeInformationOutput(sv.bossBarNotifyMode, "chat")
    sv.executeNotifyMode = NormalizeInformationOutput(sv.executeNotifyMode, "both")

    RepairBool("reticleBossEnabled")
    RepairNumber("reticleBossMinDifficulty")
    sv.reticleBossMinDifficulty = math.max(1, math.min(4, math.floor(sv.reticleBossMinDifficulty)))
    RepairNumber("reticleBossStickyMs")

    RepairBool("pvpPlayersEnabled")
    RepairNumber("pvpPlayerHoldSeconds")
    RepairNumber("pvpPlayerCooldownMs")
    RepairNumber("pvpPlayerMinDeltaPercent")
    RepairNumber("pvpStickyMs")
    RepairNumber("pvpReacquireWindowMs")
    sv.pvpPlayerNotifyMode = NormalizeInformationOutput(sv.pvpPlayerNotifyMode, "chat")

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
-- Encounter-based Challenge Difficulty
-- Public request API only. Never use private RequestOverlandDifficultyChange.
--------------------------------------------------------------
local CHALLENGE_UNCHANGED = -1
local CHALLENGE_REQUEST_INTERVAL_MS = 10000
local CHALLENGE_STABLE_MS = 800
local CHALLENGE_MAX_ATTEMPTS = 3
local challengeState = { lastRequestMs = -CHALLENGE_REQUEST_INTERVAL_MS }
local CHALLENGE_SETTINGS = {
    elite = "challengeDifficultyElite",
    boss = "challengeDifficultyBoss",
    worldEvent = "challengeDifficultyWorldEvent",
    idle = "challengeDifficultyIdle",
}
local CHALLENGE_LABELS = {
    elite = "Tough / elite enemies",
    boss = "Bosses",
    worldEvent = "World events",
    idle = "Overland difficulty",
}

local function ChallengeDifficultyChoice(value)
    if type(value) == "table" then value = value.data or value.value or value.name end
    if value == "Leave unchanged" then return CHALLENGE_UNCHANGED end
    if type(value) == "string" and GetString then
        for difficulty = 0, 3 do
            if value == GetString("SI_OVERLANDDIFFICULTYTYPE", difficulty) then return difficulty end
        end
    end
    value = tonumber(value)
    if value and value >= -1 and value <= 3 and value == math.floor(value) then return value end
    return CHALLENGE_UNCHANGED
end

local function ChallengeDifficultyName(value)
    if value == CHALLENGE_UNCHANGED then return "Leave unchanged" end
    if GetString then
        local name = GetString("SI_OVERLANDDIFFICULTYTYPE", value)
        if name and name ~= "" then return name end
    end
    return tostring(value)
end

local function ChallengeDifficultyNotice(text)
    if TargetInfoSV.challengeDifficultyNotify ~= false then ChatMsg(text, nil, "TI Mode") end
end

local function ChallengeDifficultyResetCandidate()
    challengeState.key = nil
    challengeState.sinceMs = nil
    challengeState.attempts = 0
    challengeState.failureNotified = false
    challengeState.pendingValue = nil
    challengeState.pendingLabel = nil
end

local function ChallengeDifficultyIsAllowed()
    -- ESO's own restriction query excludes PvP and bespoke-difficulty instances,
    -- including group/solo dungeons, trials, arenas and Infinite Archive.
    if IsInPvP() then return false end
    if type(GetOverlandDifficultyDisabledReason) ~= "function" then return false end
    local ok, reason = pcall(GetOverlandDifficultyDisabledReason)
    if not ok or OVERLAND_DIFFICULTY_DISABLED_REASON_NONE == nil
        or reason ~= OVERLAND_DIFFICULTY_DISABLED_REASON_NONE then return false end
    if GetCurrentZoneHouseId and GetCurrentZoneHouseId() ~= 0 then return false end
    return true
end

local function ChallengeDifficultyEncounter()
    -- Participation is authoritative; an event merely active elsewhere is ignored.
    if GetParticipatingWorldEventStep then
        local ok, instanceId = pcall(GetParticipatingWorldEventStep)
        if ok and type(instanceId) == "number" and instanceId > 0 then return "worldEvent" end
    end
    local tag = "reticleover"
    if not IsHostileAttackable(tag) or IsUnitPlayer(tag) then return "idle" end
    if type(GetUnitDifficulty) ~= "function" then return nil end
    local ok, difficulty = pcall(GetUnitDifficulty, tag)
    if not ok or type(difficulty) ~= "number" then return nil end
    if MONSTER_DIFFICULTY_DEADLY and difficulty >= MONSTER_DIFFICULTY_DEADLY then return "boss" end
    if MONSTER_DIFFICULTY_HARD and difficulty >= MONSTER_DIFFICULTY_HARD then return "elite" end
    if difficulty == MONSTER_DIFFICULTY_EASY or difficulty == MONSTER_DIFFICULTY_NORMAL then return "idle" end
    return nil -- Unknown classification must not change the game setting.
end

local function ChallengeDifficultyConfirm()
    if challengeState.pendingValue == nil or type(GetOverlandDifficulty) ~= "function" then return end
    local ok, current = pcall(GetOverlandDifficulty)
    if ok and current == challengeState.pendingValue then
        ChallengeDifficultyNotice(string.format("%s: Challenge Difficulty changed to %s.",
            challengeState.pendingLabel or "Encounter", ChallengeDifficultyName(current)))
        challengeState.pendingValue = nil
        challengeState.pendingLabel = nil
    end
end

local function ChallengeDifficultyTick()
    if TargetInfoSV.enabled ~= true or TargetInfoSV.challengeDifficultyEnabled ~= true then
        ChallengeDifficultyResetCandidate()
        challengeState.unsupportedNotified = false
        return
    end
    if type(RequestChangePlayerOverlandDifficulty) ~= "function" or type(GetOverlandDifficulty) ~= "function"
        or type(GetOverlandDifficultyDisabledReason) ~= "function" then
        if not challengeState.unsupportedNotified then
            ChallengeDifficultyNotice("Automatic Challenge Difficulty is unavailable on this game version.")
            challengeState.unsupportedNotified = true
        end
        ChallengeDifficultyResetCandidate()
        return
    end
    if not ChallengeDifficultyIsAllowed() then ChallengeDifficultyResetCandidate() return end
    -- Combat and death invalidate the candidate. Re-detect after combat rather
    -- than applying a stale request from a dead or no-longer-targeted enemy.
    if type(IsUnitInCombat) ~= "function" or IsUnitInCombat("player")
        or (IsUnitDead and IsUnitDead("player")) then ChallengeDifficultyResetCandidate() return end
    local kind = ChallengeDifficultyEncounter()
    if not kind then ChallengeDifficultyResetCandidate() return end
    local desired = ChallengeDifficultyChoice(TargetInfoSV[CHALLENGE_SETTINGS[kind]])
    if desired == CHALLENGE_UNCHANGED then ChallengeDifficultyResetCandidate() return end
    local now = NowMs()
    local zone = GetUnitZoneIndex and GetUnitZoneIndex("player") or 0
    local key = tostring(zone) .. ":" .. kind .. ":" .. tostring(desired)
    if challengeState.key ~= key then
        ChallengeDifficultyResetCandidate()
        challengeState.key = key
        challengeState.sinceMs = now
    end
    local ok, current = pcall(GetOverlandDifficulty)
    if not ok or type(current) ~= "number" then return end
    if current == desired then ChallengeDifficultyConfirm() return end
    local stableMs = kind == "idle" and 4000 or CHALLENGE_STABLE_MS
    if now - challengeState.sinceMs < stableMs then return end
    if now - challengeState.lastRequestMs < CHALLENGE_REQUEST_INTERVAL_MS then return end
    if challengeState.attempts >= CHALLENGE_MAX_ATTEMPTS then
        if not challengeState.failureNotified then
            ChallengeDifficultyNotice("Challenge Difficulty could not be changed. Check the game's cooldown or change it manually.")
            challengeState.failureNotified = true
        end
        return
    end
    challengeState.attempts = challengeState.attempts + 1
    challengeState.lastRequestMs = now
    challengeState.pendingValue = desired
    challengeState.pendingLabel = CHALLENGE_LABELS[kind]
    local requested = pcall(RequestChangePlayerOverlandDifficulty, desired)
    if not requested then
        challengeState.pendingValue = nil
        challengeState.pendingLabel = nil
    end
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
-- Per-fight memory survives healing, target switches and tracking timeouts.
local enemyFightRecords = {}
local function ResetEnemyFight()
    enemyFightRecords = {}
end

local function EnemyRecord(tag)
    local _, maximum = GetHP(tag)
    local key = tostring(SafeUniqueId(tag)) .. ":" .. tostring(maximum)
    local slot = tag:match("^boss%d+$") and tag or nil
    if not slot and BossBar_IsActive() and AreUnitsEqual then
        for i = 1, MAX_BOSSES do
            if DoesUnitExist("boss" .. i) and AreUnitsEqual(tag, "boss" .. i) then slot = "boss" .. i; break end
        end
    end
    if slot then
        local matches = 0
        for i = 1, MAX_BOSSES do
            local other = "boss" .. i
            local _, otherMaximum = GetHP(other)
            if DoesUnitExist(other) and SafeUniqueId(other) == SafeUniqueId(tag) and otherMaximum == maximum then
                matches = matches + 1
            end
        end
        -- Unique named bosses share memory across tracking methods. Only
        -- ambiguous simultaneous roster bosses need the additional slot.
        if matches > 1 then key = key .. ":" .. slot end
    end
    if not enemyFightRecords[key] then enemyFightRecords[key] = {} end
    return enemyFightRecords[key]
end

local function InitialEnemyLabel(enemy)
    local mode = TargetInfoSV.bossIdentification or "name"
    local rank = GetUnitDifficulty and GetUnitDifficulty(enemy.tag) or 0
    local label = ({ [1] = "Easy", [2] = "Normal", [3] = "Hard", [4] = "Deadly" })[rank] or "Boss"
    if mode == "difficulty" then return label end
    if mode == "both" then return enemy.name .. " (" .. label .. ")" end
    return enemy.name
end

local function IsLiveInformationEnemy(tag, expectedId)
    if not DoesUnitExist(tag) or IsUnitDead(tag) or IsUnitPlayer(tag) then return false end
    if tag:match("^boss%d+$") and not BossBar_IsActive() then return false end
    if not IsHostileAttackable(tag) then return false end
    if expectedId and SafeUniqueId(tag) ~= expectedId then return false end
    local cur, maxV = GetHP(tag)
    return cur > 0 and maxV > 0
end

local function IsDeadlyHealthEnemy(tag, expectedId)
    if not IsLiveInformationEnemy(tag, expectedId) or type(GetUnitDifficulty) ~= "function" then return false end
    local ok, rank = pcall(GetUnitDifficulty, tag)
    return ok and MONSTER_DIFFICULTY_DEADLY ~= nil and rank == MONSTER_DIFFICULTY_DEADLY
end

local function MakeEnemyInformationGuard(enemies, healthOnly)
    local encounter = enemyFightRecords
    local identities = {}
    for _, enemy in ipairs(enemies) do
        identities[#identities + 1] = { tag = enemy.tag, uid = enemy.uid or SafeUniqueId(enemy.tag) }
    end
    return function()
        if encounter ~= enemyFightRecords or not TargetInfoSV.enabled or IsUnitDead("player") then return false end
        if healthOnly and not EnemyHealthEnabled() then return false end
        if not healthOnly and not EnemyExecuteEnabled() then return false end
        for _, enemy in ipairs(identities) do
            if healthOnly then
                if not IsDeadlyHealthEnemy(enemy.tag, enemy.uid) then return false end
            elseif not IsLiveInformationEnemy(enemy.tag, enemy.uid) then return false end
        end
        return #identities > 0
    end
end

local function NotifyEnemyHealth(enemies, sound)
    if not EnemyHealthEnabled() or #enemies == 0 then return false end
    local due, records, parts, chatParts = {}, {}, {}, {}
    local step = Clamp(TargetInfoSV.bossStepPercent or 20, 10, 35)
    for _, enemy in ipairs(enemies) do
        if IsDeadlyHealthEnemy(enemy.tag, enemy.uid) then
            local record = EnemyRecord(enemy.tag)
            local cur, _, pct = GetHP(enemy.tag)
            if record.lastHealthPercent == nil or record.lastHealthPercent - pct >= step - 0.0001 then
                due[#due + 1] = enemy
                records[#records + 1] = { record = record, pct = pct }
                local health = FormatCompactNumber(cur) .. " HP"
                local label = record.identified and enemy.name or InitialEnemyLabel(enemy)
                parts[#parts + 1] = enemy.name .. " " .. health
                chatParts[#chatParts + 1] = NAME_COLOUR .. label .. "|r " .. HEALTH_COLOUR .. health .. "|r"
            end
        end
    end
    if #due == 0 then return false end
    local guard = MakeEnemyInformationGuard(due, true)
    if not guard() then return false end
    local committed = false
    local function OutputGuard()
        if not guard() then return false end
        if not committed then
            for _, item in ipairs(records) do item.record.lastHealthPercent = item.pct; item.record.identified = true end
            committed = true
        end
        return true
    end
    NotifyCustom(table.concat(parts, "; ") .. ".", TargetInfoSV.bossBarNotifyMode, BLUE, sound or SOUNDS.NONE, "boss", OutputGuard, table.concat(chatParts, "; ") .. ".")
    return true
end

local function GetDeadlyHealthBosses(bosses)
    local healthBosses = {}
    for _, boss in ipairs(bosses) do
        if IsDeadlyHealthEnemy(boss.tag, boss.uid) then healthBosses[#healthBosses + 1] = boss end
    end
    return healthBosses
end

local function GetActiveBosses()
    local bosses = {}
    for i = 1, MAX_BOSSES do
        local tag = "boss" .. i
        local cur, maxV, pct = GetHP(tag)
        if maxV > 0 and pct > 0 and IsLiveInformationEnemy(tag) then
            table.insert(bosses, {
                tag = tag,
                uid = SafeUniqueId(tag),
                name = SafeName(tag, "Boss " .. i),
                cur = cur,
                maxV = maxV,
                pct = pct,
            })
        end
    end
    return bosses
end

local function NotifyEnemyExecute(enemy)
    if not EnemyExecuteEnabled() then return end
    local record = EnemyRecord(enemy.tag)
    local _, _, pct = GetHP(enemy.tag)
    if pct <= 0 or pct > (TargetInfoSV.executePercent or 33) or record.executeFired then return end
    local guard = MakeEnemyInformationGuard({ enemy }, false)
    local label = record.identified and enemy.name or InitialEnemyLabel(enemy)
    local function OutputGuard()
        if not guard() then return false end
        record.executeFired = true
        record.identified = true
        return true
    end
    NotifyCustom(enemy.name .. " can be executed.", TargetInfoSV.executeNotifyMode, SOFTRED, SOUNDS.DUEL_START, nil, OutputGuard, RED .. label .. " can be executed.|r")
end

local function BossModeTick()
    if not BossBar_IsActive() then return end
    local bosses = GetActiveBosses()
    for _, enemy in ipairs(bosses) do NotifyEnemyExecute(enemy) end
    NotifyEnemyHealth(GetDeadlyHealthBosses(bosses))
end

local ReticleBoss = { active = false, uid = nil, name = nil, lastSeenMs = 0 }
local function ReticleBoss_Reset()
    ReticleBoss.active = false
    ReticleBoss.uid = nil
    ReticleBoss.name = nil
    ReticleBoss.lastSeenMs = 0
end

local function ReticleBoss_IsValidTarget()
    if not TargetInfoSV.reticleBossEnabled or NormalizeInformationMode(TargetInfoSV.bossUpdateMode) == "off" then return false end

    local tag = "reticleover"
    if not IsHostileAttackable(tag) then return false end
    if IsUnitPlayer and IsUnitPlayer(tag) then return false end

    local nm = (GetUnitName(tag) or ""):lower()
    if nm == "blastbones" then return false end

    if type(GetUnitDifficulty) ~= "function" then return false end
    local ok, diff = pcall(GetUnitDifficulty, tag)
    if not ok or type(diff) ~= "number" then return false end

    local minDiff = TargetInfoSV.reticleBossMinDifficulty or 3
    if diff < minDiff then return false end

    local _, maxV, pct = GetHP(tag)
    if not maxV or maxV <= 0 then return false end
    if pct <= 0 then return false end


    return true
end

local function ReticleBossTick()
    if not TargetInfoSV.reticleBossEnabled or NormalizeInformationMode(TargetInfoSV.bossUpdateMode) == "off" then
        ReticleBoss_Reset()
        return
    end
    if BossBar_IsActive() then return end
    local tag, now = "reticleover", NowMs()
    if ReticleBoss_IsValidTarget() then
        local enemy = { tag = tag, uid = SafeUniqueId(tag), name = SafeName(tag, "Enemy") }
        ReticleBoss.active, ReticleBoss.uid, ReticleBoss.name = true, enemy.uid, enemy.name
        ReticleBoss.lastSeenMs = now
        NotifyEnemyExecute(enemy)
        NotifyEnemyHealth({ enemy })
    elseif ReticleBoss.active and (now - ReticleBoss.lastSeenMs) > (TargetInfoSV.reticleBossStickyMs or 8000) * 3 then
        ReticleBoss_Reset()
    end
end

--------------------------------------------------------------
-- Tick
--------------------------------------------------------------
local function Tick()
    ChallengeDifficultyTick()
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

    settings:AddSetting({ type = LHAS.ST_SECTION, label = "Overland Encounter Difficulty" })
    settings:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Automatic Encounter Difficulty",
        tooltip = "Changes the current character's actual Challenge Difficulty before combat. Applies only where ESO enables overland difficulty: quest zones/story instances, delves and public dungeons. Excluded content and PvP are untouched. Combat and game cooldowns can prevent changes; wait for confirmation before engaging.",
        getFunction = function() return TargetInfoSV.challengeDifficultyEnabled == true end,
        setFunction = function(value) TargetInfoSV.challengeDifficultyEnabled = value == true; ChallengeDifficultyResetCandidate() end,
        default = false,
    })
    settings:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Announce Difficulty Changes",
        tooltip = "Chat confirms successful changes with the [Target Info] tag and reports unsupported APIs or exhausted retries.",
        getFunction = function() return TargetInfoSV.challengeDifficultyNotify ~= false end,
        setFunction = function(value) TargetInfoSV.challengeDifficultyNotify = value == true end,
        default = true,
    })
    local difficultyItems = { { name = "Leave unchanged", data = CHALLENGE_UNCHANGED } }
    for difficulty = 0, 3 do
        table.insert(difficultyItems, { name = ChallengeDifficultyName(difficulty), data = difficulty })
    end
    local function AddEncounterDifficultySetting(label, key, tooltip)
        settings:AddSetting({
            type = LHAS.ST_DROPDOWN,
            label = label,
            tooltip = tooltip .. " Leave unchanged preserves the last game difficulty; it does not restore a previous value. Turning automation off also leaves the current game difficulty in place.",
            items = difficultyItems,
            getFunction = function() return ChallengeDifficultyName(ChallengeDifficultyChoice(TargetInfoSV[key])) end,
            setFunction = function(controlOrValue, itemName, itemData)
                TargetInfoSV[key] = ChallengeDifficultyChoice(itemData or itemName or controlOrValue)
                ChallengeDifficultyResetCandidate()
            end,
            default = "Leave unchanged",
        })
    end
    AddEncounterDifficultySetting("Tough / Elite Enemies", "challengeDifficultyElite", "Living hostile targets rated Hard by ESO. World-event participation takes priority.")
    AddEncounterDifficultySetting("Bosses", "challengeDifficultyBoss", "Living hostile targets rated Deadly by ESO. Lower-rated enemies use Overland Difficulty or Tough / Elite Enemies.")
    AddEncounterDifficultySetting("World Events", "challengeDifficultyWorldEvent", "Uses ESO's reported world-event participation, taking priority over target difficulty ratings. Events active elsewhere do not trigger it; changes still require being out of combat.")
    AddEncounterDifficultySetting("Overland Difficulty", "challengeDifficultyIdle", "Baseline for roaming and ordinary enemies. Restored after four seconds without a tougher encounter or participating world event, when ESO permits changing difficulty.")

    settings:AddSetting({ type = LHAS.ST_SECTION, label = "Enemy Information" })

    settings:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Health Drop Between Updates",
        tooltip = "Report after health drops by this many percentage points since the last report (10% to 35%). Applies to living Deadly-ranked enemies. There is no timed repeat.",
        getFunction = function() return TargetInfoSV.bossStepPercent end,
        setFunction = function(v) TargetInfoSV.bossStepPercent = Clamp(v, 10, 35) end,
        default = 20,
        min = 10, max = 35, step = 1,
        unit = "%",
        format = "%d",
    })

    settings:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Execute Threshold",
        getFunction = function() return TargetInfoSV.executePercent end,
        setFunction = function(v) TargetInfoSV.executePercent = v end,
        default = 33,
        min = 10, max = 50, step = 1,
        unit = "%",
        format = "%d",
    })




    settings:AddSetting({
        type = LHAS.ST_DROPDOWN,
        label = "Enemy Announcements",
        tooltip = "Controls enemy health and execute announcements. Health reports require Deadly rank. Execute alerts occur once per enemy per fight. PvP callouts and difficulty notices have separate controls.",
        items = {
            { name = "OFF", data = "off" },
            { name = "EXECUTE ONLY", data = "execute" },
            { name = "HEALTH ONLY", data = "health" },
            { name = "HEALTH AND EXECUTE", data = "both" },
        },
        getFunction = function()
            local names = { off = "OFF", execute = "EXECUTE ONLY", health = "HEALTH ONLY", both = "HEALTH AND EXECUTE" }
            return names[NormalizeInformationMode(TargetInfoSV.bossUpdateMode)]
        end,
        setFunction = function(controlOrValue, itemName, itemData)
            TargetInfoSV.bossUpdateMode = NormalizeInformationMode(itemData or itemName or controlOrValue)
        end,
        default = "HEALTH AND EXECUTE",
    })

    settings:AddSetting({
        type = LHAS.ST_DROPDOWN,
        label = "Enemy Health Output",
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
        setFunction = function(controlOrValue, itemName, itemData)
            TargetInfoSV.bossBarNotifyMode = NormalizeInformationOutput(itemData or itemName or controlOrValue, "chat")
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
        setFunction = function(controlOrValue, itemName, itemData)
            TargetInfoSV.executeNotifyMode = NormalizeInformationOutput(itemData or itemName or controlOrValue, "both")
        end,
        default = "BOTH",
    })

    settings:AddSetting({
        type = LHAS.ST_DROPDOWN,
        label = "Initial Boss Identification",
        tooltip = "Choose the first chat identification: boss name, enemy difficulty rank, or both. Later health updates always use the boss name.",
        items = { { name = "BOSS NAME", data = "name" }, { name = "BOSS DIFFICULTY LEVEL", data = "difficulty" }, { name = "BOTH", data = "both" } },
        getFunction = function() return ({ name = "BOSS NAME", difficulty = "BOSS DIFFICULTY LEVEL", both = "BOTH" })[TargetInfoSV.bossIdentification] or "BOSS NAME" end,
        setFunction = function(controlOrValue, itemName, itemData)
            local value = itemData or itemName or controlOrValue
            if type(value) == "table" then value = value.data or value.name end
            value = ({ ["BOSS NAME"] = "name", ["BOSS DIFFICULTY LEVEL"] = "difficulty", BOTH = "both" })[value] or value
            if value == "name" or value == "difficulty" or value == "both" then TargetInfoSV.bossIdentification = value end
        end,
        default = "BOSS NAME",
    })

    settings:AddSetting({ type = LHAS.ST_SECTION, label = "Boss Level Tracking" })

    settings:AddSetting({
        type = LHAS.ST_CHECKBOX,
        label = "Enable Boss Level Tracking",
        tooltip = "Tracks living hostile non-player targets by ESO enemy rank. Uses the shared Enemy Announcements, Health Drop Between Updates and output settings.",
        getFunction = function() return TargetInfoSV.reticleBossEnabled end,
        setFunction = function(v) TargetInfoSV.reticleBossEnabled = v end,
        default = true,
    })

    settings:AddSetting({
        type = LHAS.ST_DROPDOWN,
        label = "Minimum Enemy Rank",
        tooltip = "Filters enemy tracking and execute alerts by ESO enemy rank. Health reports always require Deadly. This filter does not change game difficulty.",
        items = {
            { name = "EASY", data = 1 }, { name = "NORMAL", data = 2 },
            { name = "HARD", data = 3 }, { name = "DEADLY", data = 4 },
        },
        getFunction = function() return ({ "EASY", "NORMAL", "HARD", "DEADLY" })[TargetInfoSV.reticleBossMinDifficulty] or "HARD" end,
        setFunction = function(controlOrValue, itemName, itemData)
            local value = itemData or itemName or controlOrValue
            if type(value) == "table" then value = value.data or value.name end
            local names = { EASY = 1, NORMAL = 2, HARD = 3, DEADLY = 4 }
            value = names[value] or tonumber(value)
            TargetInfoSV.reticleBossMinDifficulty = value and math.max(1, math.min(4, math.floor(value))) or 3
            ReticleBoss_Reset()
        end,
        default = "HARD",
    })





    settings:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Target Lost Timeout",
        tooltip = "Seconds to retain the current target after you look away. Execute-alert memory lasts until the fight ends, even if target tracking expires.",
        getFunction = function() return (TargetInfoSV.reticleBossStickyMs or 8000) * 3 / 1000 end,
        setFunction = function(value) TargetInfoSV.reticleBossStickyMs = math.max(0, value) * 1000 / 3 end,
        default = 24, min = 0, max = 45, step = 1, unit = "s", format = "%d",
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
        tooltip = "Keeps the current player target briefly when you look away.",
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
        setFunction = function(controlOrValue, itemName, itemData)
            TargetInfoSV.pvpPlayerNotifyMode = NormalizeInformationOutput(itemData or itemName or controlOrValue, "chat")
        end,
        default = "CHAT",
    })

    settings:AddSetting({ type = LHAS.ST_SECTION, label = "Enemy Information Window" })

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
        type = LHAS.ST_SECTION,
        subMenu = false,
        label = "|cFFD700Built on tea, toast and ADHD – tested live on PS5.|r\n" ..
                "|cB427D3Su|c546D6Aga|c889764Co|cDA34CDma|r",
    })
    settings:AddSetting({
        type = LHAS.ST_LABEL,
        label = "Contact",
        tooltip = "Found an error or need to contact me about Target Info?\n\nPlayStation User / PSN: SugaComa\nEmail: eso.addons@rik-sprint.co.uk",
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
    if EVENT_OVERLAND_DIFFICULTY_CHANGED then
        EM:RegisterForEvent(ADDON_NAME .. "_ChallengeDifficulty", EVENT_OVERLAND_DIFFICULTY_CHANGED, ChallengeDifficultyConfirm)
    end
    EM:RegisterForEvent(ADDON_NAME .. "_Fight", EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
        if not inCombat then ResetEnemyFight(); ReticleBoss_Reset() end
    end)
    EM:RegisterForEvent(ADDON_NAME .. "_Zone", EVENT_PLAYER_ACTIVATED, function()
        ResetEnemyFight(); ReticleBoss_Reset()
    end)
    CreateSettings()
    EnsureMessageWindow("boss")
    EnsureMessageWindow("pvp")

    EM:UnregisterForUpdate(ADDON_NAME .. "_Tick")
    EM:RegisterForUpdate(ADDON_NAME .. "_Tick", 200, Tick)

    ChatMsg(BLUE .. "TargetInfo v1.2.5 loaded.|r")
end

local function OnAddonLoaded(event, addonName)
    if addonName ~= ADDON_NAME then return end
    EM:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    Initialize()
end

EM:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)

