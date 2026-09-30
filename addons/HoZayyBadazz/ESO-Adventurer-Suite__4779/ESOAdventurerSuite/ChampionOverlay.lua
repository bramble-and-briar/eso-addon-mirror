-- ESO Adventurer Suite
-- Movable Champion Point overlay
local EPC = ESOProgressionCoach
EPC.ChampionOverlay = EPC.ChampionOverlay or {}
local C = EPC.ChampionOverlay
local wm = WINDOW_MANAGER

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a = pcall(fn, ...)
    if not ok then return fallback end
    return a
end

-- v0.25.15 - use ESO's current Champion symbols and account-wide CP totals.
local CHAMPION_POOL_ORDER_2515 = {
    {
        disciplineType = CHAMPION_DISCIPLINE_TYPE_WORLD,
        icon = "EsoUI/Art/Champion/champion_points_stamina_icon-HUD.dds",
        fallbackName = "Craft",
    },
    {
        disciplineType = CHAMPION_DISCIPLINE_TYPE_COMBAT,
        icon = "EsoUI/Art/Champion/champion_points_magicka_icon-HUD.dds",
        fallbackName = "Warfare",
    },
    {
        disciplineType = CHAMPION_DISCIPLINE_TYPE_CONDITIONING,
        icon = "EsoUI/Art/Champion/champion_points_health_icon-HUD.dds",
        fallbackName = "Fitness",
    },
}

local function championIconText2515(texture, size)
    size = tonumber(size) or 20
    if type(zo_iconFormat) == "function" then
        return zo_iconFormat(texture, size, size)
    end
    return string.format("|t%d:%d:%s|t", size, size, texture)
end

local function getChampionPools2515()
    local totals = {}
    local names = {}
    if type(GetNumChampionDisciplines) ~= "function" or type(GetChampionDisciplineId) ~= "function" then
        return totals, names
    end

    local numDisciplines = tonumber(safe(GetNumChampionDisciplines, 0)) or 0
    for disciplineIndex = 1, numDisciplines do
        local disciplineId = tonumber(safe(GetChampionDisciplineId, 0, disciplineIndex)) or 0
        if disciplineId > 0 then
            local disciplineType = safe(GetChampionDisciplineType, nil, disciplineId)
            if disciplineType ~= nil then
                local spent = tonumber(safe(GetNumSpentChampionPoints, 0, disciplineId)) or 0
                local unspent = tonumber(safe(GetNumUnspentChampionPoints, 0, disciplineId)) or 0
                totals[disciplineType] = (totals[disciplineType] or 0) + spent + unspent
                local rawName = tostring(safe(GetChampionDisciplineName, "", disciplineId) or "")
                if rawName ~= "" then names[disciplineType] = rawName end
            end
        end
    end
    return totals, names
end

local function getEarnedChampionPoints2515()
    local earned = tonumber(safe(GetPlayerChampionPointsEarned, nil))
    if earned == nil then
        earned = tonumber(safe(GetUnitChampionPoints, 0, "player")) or 0
    end
    return math.max(0, earned)
end

local function getProgressionText2515(level, championPoints, iconSize)
    if type(ZO_GetLevelOrChampionPointsString) == "function" then
        local ok, value = pcall(ZO_GetLevelOrChampionPointsString, level, championPoints, iconSize or 22)
        if ok and value and value ~= "" then return tostring(value) end
    end
    if championPoints > 0 then return "CP " .. tostring(championPoints) end
    return "LEVEL " .. tostring(level)
end

-- v0.29.64 - Character Level / XP progression before Champion unlock.
-- The same frame automatically changes from LEVEL XP (1-49) to Champion
-- progression at level 50, so there is never a dead progression HUD period.
local function getPlayerXP2964()
    local current = tonumber(safe(GetUnitXP, 0, "player")) or 0
    local maximum = tonumber(safe(GetUnitXPMax, 0, "player")) or 0
    if maximum < 0 then maximum = 0 end
    if current < 0 then current = 0 end
    if maximum > 0 and current > maximum then current = maximum end
    return current, maximum
end

local function formatNumber2964(value)
    value = math.floor((tonumber(value) or 0) + 0.5)
    if type(ZO_CommaDelimitNumber) == "function" then
        local ok, text = pcall(ZO_CommaDelimitNumber, value)
        if ok and text then return tostring(text) end
    end
    local s = tostring(value)
    local sign, body = s:match("^([%-]?)(%d+)$")
    if not body then return s end
    local changed
    repeat
        body, changed = body:gsub("^(%d+)(%d%d%d)", "%1,%2")
    until changed == 0
    return (sign or "") .. body
end


-- v0.25.18 - Champion overlay visibility modes.
-- In gain-only mode, any newly earned Craft/Warfare/Fitness Champion Point
-- reveals the overlay for a short period, then the normal 200ms visibility
-- refresh hides it again.
local CHAMPION_GAIN_DISPLAY_MS_2518 = 10000

local function championNowMs2518()
    if type(GetFrameTimeMilliseconds) == "function" then
        local ok, value = pcall(GetFrameTimeMilliseconds)
        if ok and value ~= nil then return tonumber(value) or 0 end
    end
    if type(GetGameTimeMilliseconds) == "function" then
        local ok, value = pcall(GetGameTimeMilliseconds)
        if ok and value ~= nil then return tonumber(value) or 0 end
    end
    if type(GetTimeStamp) == "function" then
        local ok, value = pcall(GetTimeStamp)
        if ok and value ~= nil then return (tonumber(value) or 0) * 1000 end
    end
    return 0
end

function C:GetVisibilityMode2518()
    local mode = EPC.saved and tostring(EPC.saved.championOverlayVisibility or "ALWAYS") or "ALWAYS"
    if mode == "GAIN" then return "GAIN" end
    return "ALWAYS"
end

function C:IsGainWindowActive2518()
    if self:GetVisibilityMode2518() ~= "GAIN" then return true end
    local untilMs = tonumber(self.gainVisibleUntilMs2518) or 0
    return untilMs > 0 and championNowMs2518() <= untilMs
end

function C:ShowForChampionGain2518()
    self.gainVisibleUntilMs2518 = championNowMs2518() + CHAMPION_GAIN_DISPLAY_MS_2518
    self:Refresh()
end

local function setVisibilityModeCore2518(self, mode)
    if not EPC.saved then return end
    EPC.saved.championOverlayVisibility = (mode == "GAIN") and "GAIN" or "ALWAYS"
    self.gainVisibleUntilMs2518 = 0
    self:Refresh()
end

function C:Anchor()
    if not self.frame then return end
    self.frame:ClearAnchors()
    local left = tonumber(EPC.saved and EPC.saved.championOverlayLeft) or -1
    local top = tonumber(EPC.saved and EPC.saved.championOverlayTop) or -1
    if left >= 0 and top >= 0 then
        self.frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
    else
        self.frame:SetAnchor(TOP, GuiRoot, TOP, 0, 72)
    end
end

function C:Create()
    local frame = wm:CreateTopLevelWindow("EAS_ChampionOverlay")
    frame:SetDimensions(430, 68)
    frame:SetClampedToScreen(true)
    frame:SetMouseEnabled(false)
    frame:SetMovable(false)

    local bg = wm:CreateControl("EAS_ChampionOverlay_BG", frame, CT_BACKDROP)
    bg:SetAnchorFill(frame)
    bg:SetCenterColor(0.020, 0.026, 0.036, 0.82)
    bg:SetEdgeColor(0.30, 0.23, 0.10, 0.95)
    bg:SetEdgeTexture(nil, 1, 1, 1)

    local label = wm:CreateControl("EAS_ChampionOverlay_Label", frame, CT_LABEL)
    label:SetAnchor(TOPLEFT, frame, TOPLEFT, 10, 7)
    label:SetAnchor(TOPRIGHT, frame, TOPRIGHT, -10, 7)
    label:SetHeight(27)
    label:SetFont("ZoFontGameBold")
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetColor(0.95, 0.80, 0.40, 1)

    local pools = wm:CreateControl("EAS_ChampionOverlay_Pools2515", frame, CT_LABEL)
    pools:SetAnchor(TOPLEFT, frame, TOPLEFT, 8, 35)
    pools:SetAnchor(TOPRIGHT, frame, TOPRIGHT, -8, 35)
    pools:SetHeight(25)
    pools:SetFont("ZoFontGame")
    pools:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    pools:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    pools:SetColor(0.92, 0.94, 0.97, 1)

    local xpTrack = wm:CreateControl("EAS_LevelXPTrack2964", frame, CT_TEXTURE)
    xpTrack:SetTexture("EsoUI/Art/Miscellaneous/progressbar_genericfill.dds")
    xpTrack:SetColor(0.10, 0.12, 0.16, 0.92)
    xpTrack:SetAnchor(BOTTOMLEFT, frame, BOTTOMLEFT, 10, -6)
    xpTrack:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, -10, -6)
    xpTrack:SetHeight(7)
    xpTrack:SetHidden(true)

    local xpFill = wm:CreateControl("EAS_LevelXPFill2964", xpTrack, CT_TEXTURE)
    xpFill:SetTexture("EsoUI/Art/Miscellaneous/progressbar_genericfill.dds")
    xpFill:SetAnchor(TOPLEFT, xpTrack, TOPLEFT, 0, 0)
    xpFill:SetAnchor(BOTTOMLEFT, xpTrack, BOTTOMLEFT, 0, 0)
    xpFill:SetWidth(1)
    xpFill:SetColor(0.95, 0.80, 0.40, 1)

    local hint = wm:CreateControl("EAS_ChampionOverlay_Hint", frame, CT_LABEL)
    hint:SetAnchor(TOPRIGHT, frame, TOPRIGHT, -4, 1)
    hint:SetDimensions(45, 14)
    hint:SetFont("ZoFontGameSmall")
    hint:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    hint:SetText("DRAG")
    hint:SetColor(0.95, 0.80, 0.40, 1)
    hint:SetHidden(true)

    frame:SetHandler("OnMoveStop", function(control)
        if EPC.saved then
            EPC.saved.championOverlayLeft = control:GetLeft()
            EPC.saved.championOverlayTop = control:GetTop()
        end
    end)

    self.frame, self.label, self.pools2515, self.xpTrack2964, self.xpFill2964, self.hint = frame, label, pools, xpTrack, xpFill, hint
    self:Anchor()
end

local function refreshCore(self)
    if not self.frame or not EPC.saved then return end

    local level = tonumber(safe(GetUnitLevel, 0, "player")) or 0
    local isChampionStage = level >= 50 or safe(IsUnitChampion, false, "player") == true
    local show = EPC.saved.showChampionOverlay ~= false

    -- The pre-50 LEVEL / XP overlay is the primary progression overlay and is
    -- intentionally independent from Champion Point Gain Only.  At level 50
    -- the frame automatically becomes the Champion overlay and then obeys the
    -- Champion visibility preference.
    if self.layoutMode then
        show = true
    elseif show and isChampionStage and self:GetVisibilityMode2518() == "GAIN" then
        show = self:IsGainWindowActive2518()
    end
    if show and not self.layoutMode and EPC.IsGameplayHudSuppressed and EPC:IsGameplayHudSuppressed() then show = false end

    self.frame:SetHidden(not show)
    if not show then return end

    if isChampionStage then
        local cp = getEarnedChampionPoints2515()
        self.label:SetText("CHAMPION  " .. getProgressionText2515(level, cp, 22))

        local totals, names = getChampionPools2515()
        local parts = {}
        for _, poolInfo in ipairs(CHAMPION_POOL_ORDER_2515) do
            local poolType = poolInfo.disciplineType
            if poolType ~= nil then
                local icon = championIconText2515(poolInfo.icon, 20)
                local poolName = tostring(names[poolType] or poolInfo.fallbackName)
                local total = tonumber(totals[poolType]) or 0
                parts[#parts + 1] = string.format("%s %s %d", icon, poolName, total)
            end
        end
        self.pools2515:SetText(table.concat(parts, "    "))
        self.pools2515:SetHidden(false)
        if self.xpTrack2964 then self.xpTrack2964:SetHidden(true) end
    else
        local currentXP, maxXP = getPlayerXP2964()
        local percent = (maxXP > 0) and math.max(0, math.min(1, currentXP / maxXP)) or 0
        self.label:SetText(string.format("LEVEL %d", level))
        if maxXP > 0 then
            self.pools2515:SetText(string.format("XP  %s / %s    %d%%", formatNumber2964(currentXP), formatNumber2964(maxXP), math.floor(percent * 100 + 0.5)))
        else
            self.pools2515:SetText("CHARACTER EXPERIENCE")
        end
        self.pools2515:SetHidden(false)
        if self.xpTrack2964 then
            self.xpTrack2964:SetHidden(false)
            if self.xpFill2964 then
                local trackWidth = tonumber(self.xpTrack2964:GetWidth()) or 0
                self.xpFill2964:SetWidth(math.max(1, math.floor(trackWidth * percent + 0.5)))
            end
        end
    end
end

function C:SetLayoutMode(active)
    self.layoutMode = active == true
    if not self.frame then return end
    self.frame:SetMouseEnabled(self.layoutMode)
    self.frame:SetMovable(self.layoutMode)
    if self.hint then self.hint:SetHidden(not self.layoutMode) end
    self:Refresh()
end

function C:ResetPosition()
    if not EPC.saved then return end
    EPC.saved.championOverlayLeft = -1
    EPC.saved.championOverlayTop = -1
    self:Anchor()
end

local function initializeCore(self)
    self.layoutMode = false
    self.gainVisibleUntilMs2518 = 0
    self.lastEarnedChampionPoints2518 = getEarnedChampionPoints2515()
    self:Create()
    self:Refresh()
    local prefix = EPC.name .. "_ChampionOverlay"
    if EVENT_CHAMPION_POINT_UPDATE then
        EVENT_MANAGER:RegisterForEvent(prefix .. "_CP", EVENT_CHAMPION_POINT_UPDATE, function() self:HandleChampionPointEvent2518(false) end)
    end
    if EVENT_CHAMPION_POINT_GAINED then
        EVENT_MANAGER:RegisterForEvent(prefix .. "_CPGained", EVENT_CHAMPION_POINT_GAINED, function() self:HandleChampionPointEvent2518(true) end)
    end
    if EVENT_UNSPENT_CHAMPION_POINTS_CHANGED then
        EVENT_MANAGER:RegisterForEvent(prefix .. "_CPUnspent", EVENT_UNSPENT_CHAMPION_POINTS_CHANGED, function() self:HandleChampionPointEvent2518(false) end)
    end
    if EVENT_LEVEL_UPDATE then EVENT_MANAGER:RegisterForEvent(prefix .. "_Level", EVENT_LEVEL_UPDATE, function(_, unitTag) if not unitTag or unitTag == "player" then self:Refresh() end end) end
    if EVENT_EXPERIENCE_UPDATE then
        EVENT_MANAGER:RegisterForEvent(prefix .. "_XPUpdate2964", EVENT_EXPERIENCE_UPDATE, function(_, unitTag)
            if not unitTag or unitTag == "player" then self:Refresh() end
        end)
    end
    if EVENT_EXPERIENCE_GAIN then
        EVENT_MANAGER:RegisterForEvent(prefix .. "_XPGain2964", EVENT_EXPERIENCE_GAIN, function() self:Refresh() end)
    end
    if EVENT_PLAYER_ACTIVATED then
        EVENT_MANAGER:RegisterForEvent(prefix .. "_Activated", EVENT_PLAYER_ACTIVATED, function()
            self.lastEarnedChampionPoints2518 = getEarnedChampionPoints2515()
            self:Refresh()
        end)
    end
end


-- ============================================================================
-- v0.24.84 - Use Suite Champion overlay only
-- Suppresses ESO's native player Champion/XP progress HUD while the player is
-- in Champion progression, leaving the full Champion menu itself untouched.
-- ============================================================================
function C:IsChampionPlayer()
    if type(IsUnitChampion) == "function" and safe(IsUnitChampion, false, "player") == true then return true end
    local cp = tonumber(safe(GetUnitChampionPoints, 0, "player")) or 0
    return cp > 0
end

function C:SuppressNativeChampionProgress()
    if not self:IsChampionPlayer() then return end

    -- Native control used by ESO's level/Champion progress display.
    if ZO_PlayerProgress and ZO_PlayerProgress.SetHidden then ZO_PlayerProgress:SetHidden(true) end
    if ZO_PlayerProgressBar and ZO_PlayerProgressBar.SetHidden then ZO_PlayerProgressBar:SetHidden(true) end
    if ZO_PlayerProgressChampionIcon and ZO_PlayerProgressChampionIcon.SetHidden then ZO_PlayerProgressChampionIcon:SetHidden(true) end
    if ZO_PlayerProgressChampionPoints and ZO_PlayerProgressChampionPoints.SetHidden then ZO_PlayerProgressChampionPoints:SetHidden(true) end

    -- Removing the fragments prevents scenes such as inventory/menu transitions
    -- from immediately restoring the native progress overlay.
    local scenes = { HUD_SCENE, HUD_UI_SCENE }
    local fragments = { PLAYER_PROGRESS_BAR_FRAGMENT, PLAYER_PROGRESS_BAR_CURRENT_FRAGMENT }
    for _, scene in ipairs(scenes) do
        if scene and type(scene.RemoveFragment) == "function" then
            for _, fragment in ipairs(fragments) do
                if fragment then pcall(scene.RemoveFragment, scene, fragment) end
            end
        end
    end
end

-- ============================================================================
-- v0.24.85 - Champion overlay gameplay-only scene visibility
-- Refresh immediately when ESO scenes/UI mode change so the custom Champion
-- overlay disappears in Map/Inventory/Character/Skills/menus and returns when
-- normal gameplay resumes. The Suite Codex is treated as a menu as well.
-- ============================================================================
function C:IsSuiteMenuOpen()
    local journal = EPC.Journal
    local window = journal and journal.window
    if window and type(window.IsHidden) == "function" then
        local ok, hidden = pcall(window.IsHidden, window)
        if ok and hidden == false then return true end
    end
    return false
end

function C:Refresh()
    self:SuppressNativeChampionProgress()
    if self.frame and self:IsSuiteMenuOpen() and not self.layoutMode then
        self.frame:SetHidden(true)
        return
    end
    return refreshCore(self)
end

local function initializeGameplayVisibility2485(self)
    local prefix = EPC.name .. "_ChampionGameplayOnly"

    if SCENE_MANAGER and type(SCENE_MANAGER.RegisterCallback) == "function" then
        SCENE_MANAGER:RegisterCallback("SceneStateChanged", function()
            self:Refresh()
        end)
    end

    if EVENT_GAME_CAMERA_UI_MODE_CHANGED then
        EVENT_MANAGER:RegisterForEvent(prefix .. "_UIMode", EVENT_GAME_CAMERA_UI_MODE_CHANGED, function()
            self:Refresh()
        end)
    end

    EVENT_MANAGER:RegisterForUpdate(prefix .. "_Visibility", 1000, function()
        self:Refresh()
    end)
end


-- ============================================================================
-- v0.28.65 - Reliable Champion Point Gain Only detection
-- Some clients can deliver Champion events before GetPlayerChampionPointsEarned
-- has updated (or not deliver the expected update event at all).  Keep a tiny
-- gameplay-safe watcher on the real earned CP total so GAIN mode always reacts
-- to an actual account Champion Point increase.
-- ============================================================================
function C:CheckEarnedChampionPointGain2865(forceShow)
    local earned = getEarnedChampionPoints2515()
    local previous = tonumber(self.lastEarnedChampionPoints2518)

    -- First sample / character activation establishes a baseline only.
    if previous == nil then
        self.lastEarnedChampionPoints2518 = earned
        return false
    end

    -- Account/character transitions can occasionally make the sampled value
    -- move backwards temporarily.  Treat that as a new baseline, never a gain.
    if earned < previous then
        self.lastEarnedChampionPoints2518 = earned
        return false
    end

    local gained = (earned > previous)
    self.lastEarnedChampionPoints2518 = earned

    if forceShow == true or gained then
        self:ShowForChampionGain2518()
        return true
    end
    return false
end

-- Replace the older event handler with the same behavior plus the reliable
-- earned-total comparison above.
function C:HandleChampionPointEvent2518(forceGain)
    if forceGain == true then
        -- EVENT_CHAMPION_POINT_GAINED is authoritative.  Show immediately even
        -- when the account total is updated a frame later, then refresh the
        -- baseline on the follow-up watcher tick.
        self:CheckEarnedChampionPointGain2865(true)
    else
        if not self:CheckEarnedChampionPointGain2865(false) then
            self:Refresh()
        end
    end
end

function C:SetVisibilityMode2518(mode)
    -- Start GAIN mode from the current value so an old/stale baseline can never
    -- create a fake popup as soon as the setting is changed.
    self.lastEarnedChampionPoints2518 = getEarnedChampionPoints2515()
    return setVisibilityModeCore2518(self, mode)
end

function C:Initialize()
    initializeCore(self)
    self:SuppressNativeChampionProgress()

    local nativePrefix = EPC.name .. "_ChampionNativeSuppress"
    if EVENT_PLAYER_ACTIVATED then
        EVENT_MANAGER:RegisterForEvent(nativePrefix .. "_Activated", EVENT_PLAYER_ACTIVATED, function() self:SuppressNativeChampionProgress() end)
    end
    if EVENT_CHAMPION_POINT_UPDATE then
        EVENT_MANAGER:RegisterForEvent(nativePrefix .. "_CP", EVENT_CHAMPION_POINT_UPDATE, function() self:SuppressNativeChampionProgress() end)
    end

    initializeGameplayVisibility2485(self)

    local prefix = EPC.name .. "_ChampionGainWatch2865"

    -- The earned-CP fallback is deliberately low-frequency and only performs
    -- the comparison while Champion Point Gain Only is selected. Authoritative
    -- CP/XP events remain the immediate path.
    EVENT_MANAGER:RegisterForUpdate(prefix, 750, function()
        if not EPC.saved or self:GetVisibilityMode2518() ~= "GAIN" then return end
        self:CheckEarnedChampionPointGain2865(false)
    end)

    -- XP gain is a useful fast-path: Champion Points are awarded from XP, so do
    -- a few delayed checks around the award boundary. The low-frequency watcher
    -- above remains the final fallback.
    if EVENT_EXPERIENCE_GAIN then
        EVENT_MANAGER:RegisterForEvent(prefix .. "_XP", EVENT_EXPERIENCE_GAIN, function()
            if not EPC.saved or self:GetVisibilityMode2518() ~= "GAIN" then return end
            self.cpGainCheckToken2865 = (tonumber(self.cpGainCheckToken2865) or 0) + 1
            local token = self.cpGainCheckToken2865
            local function delayedCheck()
                if token ~= self.cpGainCheckToken2865 then return end
                self:CheckEarnedChampionPointGain2865(false)
            end
            if type(zo_callLater) == "function" then
                zo_callLater(delayedCheck, 100)
                zo_callLater(delayedCheck, 350)
                zo_callLater(delayedCheck, 800)
            else
                delayedCheck()
            end
        end)
    end
end
