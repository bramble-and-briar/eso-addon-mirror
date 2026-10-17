-- ===========================================================================
-- OffsetNudge.lua
-- ---------------------------------------------------------------------------
-- Hold-to-nudge for the two third-person framing axes CameraControl exposed
-- as live keybinds: horizontal offset and vertical offset.
--
-- This is a player-owned framing tool, not a cinematic override:
--   * A single HOME pose (horizontal + vertical) must be remembered from the
--     settings panel before any bind will move the camera.
--   * Hold a bind to move that axis continuously (units per second, scaled by
--     a user speed multiplier). Release to stop. Home is never rewritten by
--     a nudge -- only by the Remember / Delete buttons.
--   * Restore returns both axes to that home. Zoom, FOV, and shoulder are
--     untouched.
--   * While a context preset has a restore snapshot, the same
--     delta is applied to that snapshot so leaving the state does not rewind
--     the nudge. Snapshot persistence is flushed when the hold ends, not every
--     frame.
--
-- An optional on-screen readout shows both axes while a bind is held and for
-- OVERLAY_HOLD_MS after the last input, then hides itself. No standing per-
-- frame cost while idle: the mover and the hide timer tear themselves down.
-- ===========================================================================

local addon = BureauOfAcceptableViews
local private = addon.private

addon.OffsetNudge = addon.OffsetNudge or {}
local OffsetNudge = addon.OffsetNudge

local CameraSettings = addon.CameraSettings
local CameraResponse = addon.CameraResponse

local EVENT_MANAGER = EVENT_MANAGER
local GetGameTimeMilliseconds = GetGameTimeMilliseconds
local WINDOW_MANAGER = WINDOW_MANAGER
local GetString = GetString
local IsGameCameraSiegeControlled = IsGameCameraSiegeControlled
local tonumber = tonumber
local pcall = pcall
local mathabs = math.abs
local mathfloor = math.floor
local stringformat = string.format
local SetSetting = SetSetting

local HORIZONTAL_KEY = "horizontalOffset"
local VERTICAL_KEY = "verticalOffset"
local RESPONSE_OWNER = "OffsetNudge"

-- Engine units per second at 100% speed. Horizontal spans -1..1 (2.0);
-- vertical only -0.3..0.5 (0.8), so its rate is higher so both axes cover
-- their full range in about the same hold time (~0.25 s at 100%).
local HORIZONTAL_RATE = 4.0
local VERTICAL_RATE = 4.0

local SPEED_MIN = 0.5
local SPEED_MAX = 2.0
local SPEED_DEFAULT = 1.0

local MOVE_UPDATE_NAME = "BAV_OffsetNudge_Move"
local HIDE_UPDATE_NAME = "BAV_OffsetNudge_Hide"
local OVERLAY_HOLD_MS = 2000
local NOTICE_HOLD_MS = 2000
local MAX_DT_MS = 100
local WRITE_EPSILON = 0.005
local OVERLAY_TOP_INSET = 96
local OVERLAY_WIDTH = 560
local OVERLAY_MIN_HEIGHT = 118
local OVERLAY_PAD = 12
local OVERLAY_STATUS_GAP = 10
local OVERLAY_AXES_HEIGHT = 48

local STATUS_COLOR = {
    live       = { 0.773, 0.761, 0.620, 1 },
    blocked    = { 0.910, 0.365, 0.365, 1 },
    failed     = { 0.910, 0.365, 0.365, 1 },
    remembered = { 0.435, 0.796, 0.624, 1 },
    restored   = { 0.435, 0.796, 0.624, 1 },
    cleared    = { 0.816, 0.565, 0.369, 1 },
}

local AXIS_COLOR = { 0.773, 0.761, 0.620, 1 }

local overlay = nil
local lastMoveMs = nil
local moving = false
local noticeKind = "live"
local liveOffset = { horizontal = nil, vertical = nil }
local holdStart = { horizontal = nil, vertical = nil }

-- Setting ids cached once so the hold tick can write without CameraSettings.Set's
-- verify/Get round-trip (that path is too heavy for a per-frame nudge).
local axisMeta = {
    [HORIZONTAL_KEY] = { settingId = CAMERA_SETTING_THIRD_PERSON_HORIZONTAL_OFFSET, liveKey = "horizontal" },
    [VERTICAL_KEY]   = { settingId = CAMERA_SETTING_THIRD_PERSON_VERTICAL_OFFSET,   liveKey = "vertical" },
}

local config = {
    speed = SPEED_DEFAULT,
    overlay = true,
    home = nil,
}

local hold = {
    horizontal = 0,
    vertical = 0,
}

local function LogDebug(...)
    if private.LogDebug then private.LogDebug(...) end
end

local function Clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function InterruptPresetTransition()
    local presets = addon.ContextPresets
    if presets and presets.InterruptTransition then
        presets.InterruptTransition()
    end
end

local function AdjustRestoreOffset(key, delta)
    local presets = addon.ContextPresets
    if presets and presets.AdjustRestoreOffset then
        presets.AdjustRestoreOffset(key, delta)
    end
end

local function SetRestoreOffset(key, value)
    local presets = addon.ContextPresets
    if presets and presets.SetRestoreOffset then
        presets.SetRestoreOffset(key, value)
    end
end

local function FlushRestoreSnapshot()
    local presets = addon.ContextPresets
    if presets and presets.FlushRestoreSnapshot then
        presets.FlushRestoreSnapshot()
    end
end

local function HasHome()
    return type(config.home) == "table"
        and tonumber(config.home.horizontal) ~= nil
        and tonumber(config.home.vertical) ~= nil
end

local function ClampToKey(key, value)
    value = tonumber(value)
    if value == nil then
        return nil
    end
    local minValue, maxValue = CameraSettings.GetRange(key)
    if minValue == nil then
        return value
    end
    return Clamp(value, minValue, maxValue)
end

-- Prefer the pre-preset snapshot when a cinematic bundle is on the live camera,
-- so "remember home" stores the player's real framing rather than combat/stealth
-- offsets. Falls back to the live engine value when no snapshot exists.
local function ReadHomeAxis(key)
    local presets = addon.ContextPresets
    if presets and presets.GetRestoreOffset then
        local fromSnapshot = presets.GetRestoreOffset(key)
        if fromSnapshot ~= nil then
            return ClampToKey(key, fromSnapshot)
        end
    end
    local live, ok = CameraSettings.Get(key)
    if ok then
        return ClampToKey(key, live)
    end
    return nil
end

local function PersistHome(home)
    local settings = addon.Settings
    if settings and settings.SetOffsetNudgeHome then
        settings.SetOffsetNudgeHome(home)
    end
end

-- ESO's camera smoothing interpolates the live view toward the offset setting.
-- That lag is why the overlay number jumps while the picture crawls, especially
-- on the wide horizontal axis. Suspend smoothing for the hold, then put the
-- player's original value back on release.
local function SuspendSmoothing()
    if CameraResponse and CameraResponse.AcquireSmoothing then
        CameraResponse.AcquireSmoothing(RESPONSE_OWNER, true)
    end
end

local function RestoreSmoothing()
    if CameraResponse and CameraResponse.ReleaseSmoothing then
        CameraResponse.ReleaseSmoothing(RESPONSE_OWNER)
    end
end

local function WriteAxis(key, value)
    if not CameraSettings.IsSupported(key) then
        return false
    end
    value = ClampToKey(key, value)
    if value == nil then
        return false
    end
    if not CameraSettings.Set(key, value) then
        return false
    end
    local meta = axisMeta[key]
    if meta then
        liveOffset[meta.liveKey] = value
    end
    SetRestoreOffset(key, value)
    return true
end

-- Hold-path write: clamp, encode, SetSetting. No read-back. The live value is
-- tracked in liveOffset and committed through CameraSettings on release.
local function FastWrite(key, value)
    local meta = axisMeta[key]
    if not meta or meta.settingId == nil then
        return nil
    end
    value = ClampToKey(key, value)
    if value == nil then
        return nil
    end
    local encoded = stringformat("%.2f", value)
    local ok, setResult = pcall(SetSetting, SETTING_TYPE_CAMERA, meta.settingId, encoded)
    if not ok or setResult == false then
        return nil
    end
    return tonumber(encoded) or value
end

local function SeedLiveAxis(key)
    local meta = axisMeta[key]
    local cached = liveOffset[meta.liveKey]
    if cached ~= nil then
        return cached
    end
    local live, ok = CameraSettings.Get(key)
    if ok then
        liveOffset[meta.liveKey] = live
        return live
    end
    return nil
end

local function NudgeKey(key, delta)
    if delta == 0 or not HasHome() then
        return false
    end

    local meta = axisMeta[key]
    local live = SeedLiveAxis(key)
    if live == nil or meta == nil then
        return false
    end

    local requested = FastWrite(key, live + delta)
    if requested == nil then
        return false
    end
    if mathabs(requested - live) < WRITE_EPSILON then
        liveOffset[meta.liveKey] = requested
        return false
    end

    liveOffset[meta.liveKey] = requested
    return true
end

local function CommitHoldDeltas()
    local restoreChanged = false
    for key, meta in pairs(axisMeta) do
        local startValue = holdStart[meta.liveKey]
        local endValue = liveOffset[meta.liveKey]
        if startValue ~= nil and endValue ~= nil then
            CameraSettings.Set(key, endValue, WRITE_EPSILON)
            local appliedValue, hasApplied = CameraSettings.Get(key)
            local committed = hasApplied
                and mathabs(appliedValue - endValue) <= WRITE_EPSILON

            if committed then
                liveOffset[meta.liveKey] = appliedValue
                local delta = appliedValue - startValue
                if mathabs(delta) >= WRITE_EPSILON then
                    AdjustRestoreOffset(key, delta)
                    restoreChanged = true
                end
            else
                liveOffset[meta.liveKey] = hasApplied and appliedValue or nil
                LogDebug("OffsetNudge: release commit failed for %s", key)
            end
        end
        holdStart[meta.liveKey] = nil
    end
    if restoreChanged then
        FlushRestoreSnapshot()
    end
end

local function AxisPercentAndArrow(key, value)
    local minValue, maxValue = CameraSettings.GetRange(key)
    if minValue == nil or value == nil then
        return GetString(SI_BAV_NUDGE_OVERLAY_CENTER), "."
    end

    local span = value >= 0 and maxValue or mathabs(minValue)
    if span <= 0 then
        return GetString(SI_BAV_NUDGE_OVERLAY_CENTER), "."
    end

    local percent = mathfloor((mathabs(value) / span) * 100 + 0.5)
    if percent <= 0 then
        return GetString(SI_BAV_NUDGE_OVERLAY_CENTER), "."
    end

    local arrow = "."
    if key == HORIZONTAL_KEY then
        arrow = value < 0 and "<" or ">"
    else
        arrow = value < 0 and "v" or "^"
    end
    return stringformat(GetString(SI_BAV_NUDGE_OVERLAY_PERCENT), percent), arrow
end

local function FormatAxisLine(label, key, value)
    local text, arrow = AxisPercentAndArrow(key, value)
    return stringformat("%s  %s  %s", label, arrow, text)
end

local function EnsureOverlay()
    if overlay then
        return overlay
    end

    local wm = WINDOW_MANAGER
    if not wm or not wm.CreateTopLevelWindow then
        return nil
    end

    local top = wm:CreateTopLevelWindow("BAVOffsetNudgeOverlay")
    top:SetHidden(true)
    top:SetMouseEnabled(false)
    top:SetMovable(false)
    top:SetClampedToScreen(true)
    top:SetAnchor(TOP, GuiRoot, TOP, 0, OVERLAY_TOP_INSET)
    top:SetDimensions(OVERLAY_WIDTH, OVERLAY_MIN_HEIGHT)
    top:SetDrawLayer(DL_OVERLAY)
    top:SetDrawTier(DT_HIGH)
    top:SetDrawLevel(10)

    local bg = wm:CreateControl("BAVOffsetNudgeOverlayBg", top, CT_BACKDROP)
    bg:SetAnchorFill()
    bg:SetCenterColor(0, 0, 0, 0.62)
    bg:SetEdgeColor(0.435, 0.796, 0.624, 0.45)

    local innerWidth = OVERLAY_WIDTH - (OVERLAY_PAD * 2)

    local status = wm:CreateControl("BAVOffsetNudgeOverlayStatus", top, CT_LABEL)
    status:SetAnchor(TOP, top, TOP, 0, OVERLAY_PAD)
    status:SetWidth(innerWidth)
    status:SetFont("ZoFontWinH4")
    status:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    status:SetVerticalAlignment(TEXT_ALIGN_TOP)
    status:SetColor(AXIS_COLOR[1], AXIS_COLOR[2], AXIS_COLOR[3], AXIS_COLOR[4])
    status:SetText("")

    local axes = wm:CreateControl("BAVOffsetNudgeOverlayAxes", top, CT_LABEL)
    axes:SetAnchor(TOP, status, BOTTOM, 0, OVERLAY_STATUS_GAP)
    axes:SetDimensions(innerWidth, OVERLAY_AXES_HEIGHT)
    axes:SetFont("ZoFontWinH4")
    axes:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    axes:SetVerticalAlignment(TEXT_ALIGN_TOP)
    axes:SetColor(AXIS_COLOR[1], AXIS_COLOR[2], AXIS_COLOR[3], AXIS_COLOR[4])
    axes:SetText("")

    overlay = { top = top, status = status, axes = axes, bg = bg }
    return overlay
end

local function HideOverlay()
    EVENT_MANAGER:UnregisterForUpdate(HIDE_UPDATE_NAME)
    if overlay and overlay.top then
        overlay.top:SetHidden(true)
    end
end

local function IsHolding()
    return hold.horizontal ~= 0 or hold.vertical ~= 0
end

local function RefreshOverlay()
    if not config.overlay then
        HideOverlay()
        return
    end

    local ui = EnsureOverlay()
    if not ui then
        return
    end

    local title
    if noticeKind == "blocked" then
        title = GetString(SI_BAV_NUDGE_OVERLAY_BLOCKED)
    elseif noticeKind == "failed" then
        title = GetString(SI_BAV_NUDGE_OVERLAY_FAILED)
    elseif noticeKind == "remembered" then
        title = GetString(SI_BAV_NUDGE_OVERLAY_REMEMBERED)
    elseif noticeKind == "cleared" then
        title = GetString(SI_BAV_NUDGE_OVERLAY_CLEARED)
    elseif noticeKind == "restored" then
        title = GetString(SI_BAV_NUDGE_OVERLAY_RESTORED)
    else
        title = GetString(SI_BAV_NUDGE_OVERLAY_LIVE)
    end

    local color = STATUS_COLOR[noticeKind] or STATUS_COLOR.live
    ui.status:SetColor(color[1], color[2], color[3], color[4])
    ui.status:SetWidth(OVERLAY_WIDTH - (OVERLAY_PAD * 2))
    ui.status:SetText(title)
    local statusHeight = ui.status:GetTextHeight()
    if statusHeight < 22 then
        statusHeight = 22
    end
    ui.status:SetHeight(statusHeight)
    ui.top:SetHeight(OVERLAY_PAD + statusHeight + OVERLAY_STATUS_GAP + OVERLAY_AXES_HEIGHT + OVERLAY_PAD)
    ui.bg:SetEdgeColor(color[1], color[2], color[3], 0.55)

    local horizontal = liveOffset.horizontal
    if horizontal == nil then
        horizontal = CameraSettings.Get(HORIZONTAL_KEY)
    end
    local vertical = liveOffset.vertical
    if vertical == nil then
        vertical = CameraSettings.Get(VERTICAL_KEY)
    end
    ui.axes:SetText(stringformat("%s\n%s",
        FormatAxisLine(GetString(SI_BAV_NUDGE_OVERLAY_HORIZONTAL), HORIZONTAL_KEY, horizontal),
        FormatAxisLine(GetString(SI_BAV_NUDGE_OVERLAY_VERTICAL), VERTICAL_KEY, vertical)))
    ui.top:SetHidden(false)
end

local function CancelHideTimer()
    EVENT_MANAGER:UnregisterForUpdate(HIDE_UPDATE_NAME)
end

local function ScheduleHide(durationMs)
    CancelHideTimer()
    if not config.overlay then
        HideOverlay()
        return
    end
    EVENT_MANAGER:RegisterForUpdate(HIDE_UPDATE_NAME, durationMs or OVERLAY_HOLD_MS, function()
        HideOverlay()
        noticeKind = "live"
    end)
end

local function ShowNotice(kind, durationMs)
    noticeKind = kind or "live"
    RefreshOverlay()
    if not IsHolding() then
        ScheduleHide(durationMs or NOTICE_HOLD_MS)
    end
end

function OffsetNudge.IsHolding()
    return IsHolding()
end

local function StopMover()
    if not moving then
        RestoreSmoothing()
        return
    end
    EVENT_MANAGER:UnregisterForUpdate(MOVE_UPDATE_NAME)
    moving = false
    lastMoveMs = nil
    CommitHoldDeltas()
    RestoreSmoothing()
end

local function Tick()
    if not HasHome() then
        return
    end
    if IsGameCameraSiegeControlled and IsGameCameraSiegeControlled() then
        return
    end

    local now = GetGameTimeMilliseconds()
    local dtMs = lastMoveMs and (now - lastMoveMs) or 16
    lastMoveMs = now
    if dtMs < 0 then
        dtMs = 16
    elseif dtMs > MAX_DT_MS then
        dtMs = MAX_DT_MS
    end

    local dt = dtMs / 1000
    local speed = config.speed
    local changed = false

    if hold.horizontal ~= 0 then
        if NudgeKey(HORIZONTAL_KEY, hold.horizontal * HORIZONTAL_RATE * speed * dt) then
            changed = true
        end
    end
    if hold.vertical ~= 0 then
        if NudgeKey(VERTICAL_KEY, hold.vertical * VERTICAL_RATE * speed * dt) then
            changed = true
        end
    end

    if changed then
        RefreshOverlay()
    end
end

local function CaptureHoldStarts()
    holdStart.horizontal = SeedLiveAxis(HORIZONTAL_KEY)
    holdStart.vertical = SeedLiveAxis(VERTICAL_KEY)
end

local function StartMover()
    if moving or not HasHome() then
        return
    end
    SuspendSmoothing()
    InterruptPresetTransition()
    CaptureHoldStarts()
    lastMoveMs = GetGameTimeMilliseconds()
    moving = true
    EVENT_MANAGER:RegisterForUpdate(MOVE_UPDATE_NAME, 0, Tick)
end

local function AfterHoldChanged()
    if IsHolding() then
        CancelHideTimer()
        StartMover()
        noticeKind = "live"
        RefreshOverlay()
        return
    end

    StopMover()
    RefreshOverlay()
    ScheduleHide()
end

local function SetAxisHold(axis, direction, down)
    if down then
        hold[axis] = direction
    elseif hold[axis] == direction then
        hold[axis] = 0
    end
    AfterHoldChanged()
end

local function RejectWithoutHome()
    hold.horizontal = 0
    hold.vertical = 0
    StopMover()
    ShowNotice("blocked", NOTICE_HOLD_MS)
end

-- ---------------------------------------------------------------------------
-- Public bind entry points (Bindings.xml)
-- ---------------------------------------------------------------------------

function OffsetNudge.StartHorizontal(direction)
    if not HasHome() then
        RejectWithoutHome()
        return
    end
    SetAxisHold("horizontal", direction, true)
end

function OffsetNudge.StopHorizontal(direction)
    SetAxisHold("horizontal", direction, false)
end

function OffsetNudge.StartVertical(direction)
    if not HasHome() then
        RejectWithoutHome()
        return
    end
    SetAxisHold("vertical", direction, true)
end

function OffsetNudge.StopVertical(direction)
    SetAxisHold("vertical", direction, false)
end

function OffsetNudge.Recenter()
    hold.horizontal = 0
    hold.vertical = 0
    StopMover()

    if not HasHome() then
        ShowNotice("blocked", NOTICE_HOLD_MS)
        return
    end

    if IsGameCameraSiegeControlled and IsGameCameraSiegeControlled() then
        ShowNotice("failed", NOTICE_HOLD_MS)
        return false
    end

    InterruptPresetTransition()
    SuspendSmoothing()
    local horizontalWritten = WriteAxis(HORIZONTAL_KEY, config.home.horizontal)
    local verticalWritten = WriteAxis(VERTICAL_KEY, config.home.vertical)
    if horizontalWritten or verticalWritten then
        FlushRestoreSnapshot()
    end
    RestoreSmoothing()

    if horizontalWritten and verticalWritten then
        ShowNotice("restored", NOTICE_HOLD_MS)
        LogDebug("OffsetNudge.Recenter: restored home H=%.2f V=%.2f",
            config.home.horizontal, config.home.vertical)
        return true
    end

    ShowNotice("failed", NOTICE_HOLD_MS)
    LogDebug("OffsetNudge.Recenter: restore incomplete H=%s V=%s",
        tostring(horizontalWritten), tostring(verticalWritten))
    return false
end

function OffsetNudge.RememberHome()
    if IsGameCameraSiegeControlled and IsGameCameraSiegeControlled() then
        ShowNotice("failed", NOTICE_HOLD_MS)
        return false
    end

    local horizontal = ReadHomeAxis(HORIZONTAL_KEY)
    local vertical = ReadHomeAxis(VERTICAL_KEY)
    if horizontal == nil or vertical == nil then
        ShowNotice("failed", NOTICE_HOLD_MS)
        return false
    end

    config.home = {
        horizontal = horizontal,
        vertical = vertical,
    }
    PersistHome(config.home)
    liveOffset.horizontal = horizontal
    liveOffset.vertical = vertical
    ShowNotice("remembered", NOTICE_HOLD_MS)
    LogDebug("OffsetNudge.RememberHome: H=%.2f V=%.2f", horizontal, vertical)
    return true
end

function OffsetNudge.ClearHome()
    hold.horizontal = 0
    hold.vertical = 0
    StopMover()
    config.home = nil
    PersistHome(nil)
    ShowNotice("cleared", NOTICE_HOLD_MS)
    LogDebug("OffsetNudge.ClearHome: home pose deleted")
    return true
end

function OffsetNudge.HasHome()
    return HasHome()
end

function OffsetNudge.GetHome()
    if not HasHome() then
        return nil
    end
    return {
        horizontal = config.home.horizontal,
        vertical = config.home.vertical,
    }
end

-- Panic / teardown: drop holds, hide the readout, leave the live camera as-is.
function OffsetNudge.StopAll()
    hold.horizontal = 0
    hold.vertical = 0
    RestoreSmoothing()
    StopMover()
    HideOverlay()
    noticeKind = "live"
end

function OffsetNudge.Configure(options)
    options = options or {}

    if options.speed ~= nil then
        config.speed = Clamp(tonumber(options.speed) or config.speed, SPEED_MIN, SPEED_MAX)
    end

    if options.overlay ~= nil then
        config.overlay = options.overlay and true or false
        if not config.overlay then
            HideOverlay()
        elseif IsHolding() then
            RefreshOverlay()
        end
    end

    if options.home ~= nil then
        if type(options.home) == "table" then
            local horizontal = ClampToKey(HORIZONTAL_KEY, options.home.horizontal)
            local vertical = ClampToKey(VERTICAL_KEY, options.home.vertical)
            if horizontal ~= nil and vertical ~= nil then
                config.home = { horizontal = horizontal, vertical = vertical }
            else
                config.home = nil
            end
        else
            config.home = nil
        end
    end
end

function OffsetNudge.GetSpeed()
    return config.speed
end

function OffsetNudge.IsOverlayEnabled()
    return config.overlay
end

-- A load screen can swallow the key-up. Drop any held axis so we never keep
-- writing offsets after the world unloads.
EVENT_MANAGER:RegisterForEvent("BAV_OffsetNudge", EVENT_PLAYER_DEACTIVATED, function()
    OffsetNudge.StopAll()
end)
