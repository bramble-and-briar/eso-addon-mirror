-- StatsForNerds v1.1.0
-- Real-time FPS, 1% low FPS, ping latency, desync, and packet loss.
-- Console-friendly overlay with LibAddonMenu-2.0 colour theming.

StatsForNerds = {}
local SNS = StatsForNerds

SNS.name         = "StatsForNerds"
SNS.displayName  = "Stats For Nerds"
SNS.version      = "1.0.0"

-- ─── Config ─────────────────────────────────────────────────────────────────

local UPDATE_INTERVAL_MS  = 1000    -- refresh every second
local FPS_BUFFER_SIZE     = 300     -- 5 minutes of 1-Hz samples for 1% low
local PING_BUFFER_SIZE    = 60      -- 60-second window for network stats

-- Packet-loss heuristics
local PING_TIMEOUT_THRESHOLD = 2000 -- ms; treat as "lost" if ping ≥ this
-- A sample is also "lost" if it is 0 (no data from engine).

-- Bar max scales (capped for visual clarity)
local FPS_MAX      = 120
local LATENCY_MAX  = 500   -- ms
local DESYNC_MAX   = 20   -- ms (jitter bar scale)
local PING_SPIKE_DELTA = 40   -- ms rise between samples = spike  (CombatMetrics standard)
local PING_DIP_DELTA   = 25   -- ms drop between samples = dip    (CombatMetrics standard)
local PKTLOSS_MAX  = 100   -- %
local FPS_1LOW_MIN_SAMPLES = 100  -- need 100 s of data for a true 1% low

-- ─── Defaults (trans pride palette) ─────────────────────────────────────────

local DEFAULTS = {
    x           = 30,
    y           = 30,
    showOverlay = true,
    accentR     = 0.357,  -- #5BCEFA light blue
    accentG     = 0.792,
    accentB     = 0.980,
    bgR         = 0.047,  -- #0C1025 dark navy
    bgG         = 0.063,
    bgB         = 0.145,
    bgAlpha     = 0,      -- transparent background
}

-- ─── Performance color thresholds ─────────────────────────────────────────

local COLOR_GOOD = { 0.20, 0.85, 0.25 }  -- green  (low ping / high fps)
local COLOR_WARN = { 0.95, 0.80, 0.10 }  -- yellow (medium)
local COLOR_BAD  = { 0.95, 0.25, 0.20 }  -- red    (high ping / low fps)

local function PingColor(ms)
    if ms <= 60  then return COLOR_GOOD
    elseif ms <= 120 then return COLOR_WARN
    else return COLOR_BAD end
end

local function FpsColor(fps)
    if fps >= 60 then return COLOR_GOOD
    elseif fps >= 30 then return COLOR_WARN
    else return COLOR_BAD end
end

local function SetPerfColor(ref, c)
    ref.value:SetColor(c[1], c[2], c[3], 1)
end

-- ─── State ──────────────────────────────────────────────────────────────────

local fpsBuffer    = {}
local pingBuffer   = {}
local spikeBuffer  = {}   -- 1=spike, -1=dip, 0=clean per sample (same window as pingBuffer)
local lastPingSample  = nil   -- previous valid ping for delta calc
local sessionSpikes   = 0
local sessionDips     = 0
local maxPing      = 0    -- session high-water mark
local uiRefs       = {}   -- controls that need recoloring

-- ─── Helpers ────────────────────────────────────────────────────────────────

local function PushSample(buf, value, maxSize)
    buf[#buf + 1] = value
    if #buf > maxSize then
        table.remove(buf, 1)
    end
end

local function Average(buf)
    if #buf == 0 then return 0 end
    local s = 0
    for i = 1, #buf do s = s + buf[i] end
    return s / #buf
end

-- Returns the mean of the bottom (pct * 100)% of values.
-- For 1% low: pct = 0.01
local function PercentileLow(buf, pct)
    if #buf == 0 then return 0 end
    local sorted = {}
    for i = 1, #buf do sorted[i] = buf[i] end
    table.sort(sorted)
    local count = math.max(1, math.floor(#sorted * pct))
    local s = 0
    for i = 1, count do s = s + sorted[i] end
    return s / count
end

-- Estimate packet loss over the buffer as a percentage.
-- A sample is "lost" when the engine returns 0 (no response) or the value
-- exceeds PING_TIMEOUT_THRESHOLD (severe spike — retransmit / drop).
local function PacketLoss(buf)
    if #buf < 5 then return 0 end
    local lost = 0
    for i = 1, #buf do
        local v = buf[i]
        if v == 0 or v >= PING_TIMEOUT_THRESHOLD then
            lost = lost + 1
        end
    end
    return (lost / #buf) * 100
end

-- Mean absolute deviation between consecutive samples (kept for slash-command reference).
local function Jitter(buf)
    if #buf < 2 then return 0 end
    local s = 0
    for i = 2, #buf do s = s + math.abs(buf[i] - buf[i - 1]) end
    return s / (#buf - 1)
end

-- Count spike events in the spike buffer (CombatMetrics model).
local function CountSpikes(buf)
    local n = 0
    for i = 1, #buf do if buf[i] == 1 then n = n + 1 end end
    return n
end

-- ─── Color application ──────────────────────────────────────────────────────

function SNS:ApplyColors()
    local r  = self.saved.accentR
    local g  = self.saved.accentG
    local b  = self.saved.accentB
    local br = self.saved.bgR
    local bg = self.saved.bgG
    local bb = self.saved.bgB
    local ba = self.saved.bgAlpha

    -- Border fades with the background, so alpha 0 means fully transparent
    uiRefs.bg:SetCenterColor(br, bg, bb, ba)
    uiRefs.bg:SetEdgeColor(r, g, b, math.min(ba, 0.80))

    for _, row in ipairs(uiRefs.rows) do
        row.lbl:SetColor(r, g, b, 0.55)
        row.value:SetColor(r, g, b, 1)
    end
end

-- ─── Update loop ────────────────────────────────────────────────────────────

local function Tick()
    -- Sample engine
    local fps     = GetFramerate()
    local ping    = GetLatency()       -- RTT in ms; 0 when no data

    PushSample(fpsBuffer,  fps,  FPS_BUFFER_SIZE)
    PushSample(pingBuffer, ping, PING_BUFFER_SIZE)
    if ping > 0 then
        if lastPingSample ~= nil then
            local delta = ping - lastPingSample
            if delta >= PING_SPIKE_DELTA then
                PushSample(spikeBuffer, 1,  PING_BUFFER_SIZE)
                sessionSpikes = sessionSpikes + 1
            elseif delta <= -PING_DIP_DELTA then
                PushSample(spikeBuffer, -1, PING_BUFFER_SIZE)
                sessionDips = sessionDips + 1
            else
                PushSample(spikeBuffer, 0,  PING_BUFFER_SIZE)
            end
        end
        lastPingSample = ping
        if ping > maxPing then maxPing = ping end
    end

    -- Derived stats
    local avgPing  = Average(pingBuffer)
    local desync   = Jitter(pingBuffer)         -- mean abs deviation (ms), like CombatMetrics desync
    local spikes   = CountSpikes(spikeBuffer)  -- spike events in rolling 60-s window
    local pktLoss  = PacketLoss(pingBuffer)

    -- FPS
    uiRefs.fps.value:SetText(string.format("%.0f", fps))
    SetPerfColor(uiRefs.fps, FpsColor(fps))

    -- 1% low FPS (only meaningful once 100 samples are recorded)
    if #fpsBuffer >= FPS_1LOW_MIN_SAMPLES then
        local fps1Low = PercentileLow(fpsBuffer, 0.01)
        uiRefs.fps1Low.value:SetText(string.format("%.0f", fps1Low))
        SetPerfColor(uiRefs.fps1Low, FpsColor(fps1Low))
    else
        uiRefs.fps1Low.value:SetText("--")
    end

    -- Latency (current RTT, coloured by rolling average)
    uiRefs.latency.value:SetText(string.format("%d ms", math.floor(ping + 0.5)))
    SetPerfColor(uiRefs.latency, PingColor(avgPing))

    -- Desync: mean abs deviation of ping in ms (matches CombatMetrics desync display)
    uiRefs.desync.value:SetText(string.format("%d ms", math.floor(desync + 0.5)))

    -- Packet loss
    uiRefs.pktLoss.value:SetText(string.format("%.1f%%", pktLoss))

    zo_callLater(Tick, UPDATE_INTERVAL_MS)
end

-- ─── UI construction ────────────────────────────────────────────────────────

local PAD       = 8
local LINE_H    = 30
local LABEL_GAP = 6    -- between a label and its value
local CELL_GAP  = 16   -- between one stat and the next

-- Adds one "LABEL value" cell to the line at xOffset.
-- Returns the cell refs and the x offset where the next cell starts.
local function MakeCell(parent, labelText, xOffset, valueWidth)
    local wm = WINDOW_MANAGER

    local lbl = wm:CreateControl(nil, parent, CT_LABEL)
    lbl:SetAnchor(LEFT, parent, LEFT, xOffset, 0)
    lbl:SetFont("ZoFontGamepad22")
    lbl:SetColor(1, 1, 1, 0.55)
    lbl:SetText(labelText)

    local valX = xOffset + lbl:GetTextWidth() + LABEL_GAP

    -- Fixed-width value slot so the line doesn't shift as numbers change
    local val = wm:CreateControl(nil, parent, CT_LABEL)
    val:SetAnchor(LEFT, parent, LEFT, valX, 0)
    val:SetDimensions(valueWidth, LINE_H)
    val:SetFont("ZoFontGamepad22")
    val:SetColor(1, 1, 1, 1)
    val:SetText("--")
    val:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    val:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    return { lbl = lbl, value = val }, valX + valueWidth + CELL_GAP
end

function SNS:BuildUI()
    local wm = WINDOW_MANAGER

    local startX = self.saved.x or 30
    local startY = self.saved.y or 30

    local root = wm:CreateTopLevelWindow("StatsForNerdsRoot")
    root:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, startX, startY)
    root:SetMovable(true)
    root:SetMouseEnabled(true)
    root:SetClampedToScreen(true)
    root:SetHidden(not self.saved.showOverlay)

    root:SetHandler("OnMoveStop", function(ctrl)
        self.saved.x = ctrl:GetLeft()
        self.saved.y = ctrl:GetTop()
    end)

    -- Backdrop (transparent by default; opacity comes from the Background Color setting)
    local bg = wm:CreateControl(nil, root, CT_BACKDROP)
    bg:SetAnchorFill(root)
    bg:SetCenterColor(0, 0, 0, 0)
    bg:SetEdgeColor(0, 0, 0, 0)
    bg:SetEdgeTexture(nil, 1, 1, 0, 0)

    -- One line: FPS | 1% LOW | PING | DESYNC | LOSS
    local x = PAD
    local fps, fps1Low, latency, desync, pktLoss
    fps,     x = MakeCell(root, "FPS",    x, 44)
    fps1Low, x = MakeCell(root, "1% LOW", x, 44)
    latency, x = MakeCell(root, "PING",   x, 84)
    desync,  x = MakeCell(root, "DESYNC", x, 72)
    pktLoss, x = MakeCell(root, "LOSS",   x, 80)

    root:SetDimensions(x - CELL_GAP + PAD, LINE_H)

    uiRefs.fps     = fps
    uiRefs.fps1Low = fps1Low
    uiRefs.latency = latency
    uiRefs.desync  = desync
    uiRefs.pktLoss = pktLoss
    uiRefs.bg      = bg
    uiRefs.rows    = { fps, fps1Low, latency, desync, pktLoss }

    self.rootControl = root
end

-- ─── LibAddonMenu-2.0 settings ────────────────────────────────────────────

function SNS:RegisterSettings()
    if not LibAddonMenu2 then return end
    local LAM = LibAddonMenu2

    local panelData = {
        type             = "panel",
        name             = "Stats For Nerds",
        displayName      = "Stats For Nerds",
        author           = "Vixen Hunny",
        version          = SNS.version,
        slashCommand     = "/sfnsettings",
        registerForRefresh = true,
    }

    local optionsData = {
        {
            type = "description",
            text = "Configure the overlay appearance. All changes apply live.",
        },
        {
            type    = "colorpicker",
            name    = "Accent Color",
            tooltip = "Color applied to the labels and the border.",
            getFunc = function()
                return self.saved.accentR, self.saved.accentG, self.saved.accentB, 1
            end,
            setFunc = function(r, g, b, _)
                self.saved.accentR = r
                self.saved.accentG = g
                self.saved.accentB = b
                self:ApplyColors()
            end,
        },
        {
            type    = "colorpicker",
            name    = "Background Color",
            tooltip = "Fill color and opacity of the overlay background. Transparent by default; raise the alpha to bring it back.",
            getFunc = function()
                return self.saved.bgR, self.saved.bgG, self.saved.bgB, self.saved.bgAlpha
            end,
            setFunc = function(r, g, b, a)
                self.saved.bgR    = r
                self.saved.bgG    = g
                self.saved.bgB    = b
                self.saved.bgAlpha = a
                self:ApplyColors()
            end,
        },
        {
            type    = "checkbox",
            name    = "Show Overlay",
            tooltip = "Toggle the stats overlay on or off.",
            getFunc = function() return self.saved.showOverlay end,
            setFunc = function(val)
                self.saved.showOverlay = val
                self.rootControl:SetHidden(not val)
            end,
        },
        {
            type    = "header",
            name    = "Position",
        },
        {
            type         = "slider",
            name         = "X Position",
            tooltip      = "Horizontal position of the overlay (pixels from left edge).",
            min          = 0,
            max          = 1800,
            step         = 1,
            getFunc      = function() return self.saved.x end,
            setFunc      = function(val)
                self.saved.x = val
                self.rootControl:ClearAnchors()
                self.rootControl:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self.saved.x, self.saved.y)
            end,
        },
        {
            type         = "slider",
            name         = "Y Position",
            tooltip      = "Vertical position of the overlay (pixels from top edge).",
            min          = 0,
            max          = 1000,
            step         = 1,
            getFunc      = function() return self.saved.y end,
            setFunc      = function(val)
                self.saved.y = val
                self.rootControl:ClearAnchors()
                self.rootControl:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self.saved.x, self.saved.y)
            end,
        },
        {
            type    = "button",
            name    = "Reset Position",
            tooltip = "Move the overlay back to the default top-left position.",
            func    = function()
                self.saved.x, self.saved.y = 30, 30
                self.rootControl:ClearAnchors()
                self.rootControl:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 30, 30)
                LAM:RefreshPanel(SNS.name)
            end,
        },
        {
            type    = "button",
            name    = "Reset to Defaults",
            tooltip = "Restore accent and background to the default trans pride palette.",
            func    = function()
                self.saved.accentR  = DEFAULTS.accentR
                self.saved.accentG  = DEFAULTS.accentG
                self.saved.accentB  = DEFAULTS.accentB
                self.saved.bgR      = DEFAULTS.bgR
                self.saved.bgG      = DEFAULTS.bgG
                self.saved.bgB      = DEFAULTS.bgB
                self.saved.bgAlpha  = DEFAULTS.bgAlpha
                self:ApplyColors()
                LAM:RefreshPanel(SNS.name)
            end,
        },
    }

    LAM:RegisterAddonPanel(SNS.name, panelData)
    LAM:RegisterOptionControls(SNS.name, optionsData)
end

-- ─── Slash commands ─────────────────────────────────────────────────────────

local function ColorStr(text, c)
    return string.format("|c%02X%02X%02X%s|r",
        math.floor(c[1] * 255 + 0.5),
        math.floor(c[2] * 255 + 0.5),
        math.floor(c[3] * 255 + 0.5),
        text)
end

local function DesyncColor(ms)
    if ms < 20  then return COLOR_GOOD
    elseif ms < 50 then return COLOR_WARN
    else return COLOR_BAD end
end

local function PktLossColor(pct)
    if pct < 1   then return COLOR_GOOD
    elseif pct < 5 then return COLOR_WARN
    else return COLOR_BAD end
end

local function SayMetric(label, value)
    CHAT_ROUTER:AddSystemMessage(string.format("[StatsForNerds] %s: %s", label, value))
end

local function PrintAllStats()
    local fps     = GetFramerate()
    local ping    = GetLatency()
    local avg     = Average(pingBuffer)
    local desync  = Jitter(pingBuffer)
    local spikes  = CountSpikes(spikeBuffer)
    local pktLoss = PacketLoss(pingBuffer)
    CHAT_ROUTER:AddSystemMessage("--- Stats For Nerds ---")
    CHAT_ROUTER:AddSystemMessage(string.format("FPS:           %s",
        ColorStr(string.format("%.0f", fps), FpsColor(fps))))
    local fps1LowStr
    if #fpsBuffer >= FPS_1LOW_MIN_SAMPLES then
        local v = PercentileLow(fpsBuffer, 0.01)
        fps1LowStr = ColorStr(string.format("%.0f", v), FpsColor(v))
    else
        fps1LowStr = string.format("collecting... (%d/100 s)", #fpsBuffer)
    end
    CHAT_ROUTER:AddSystemMessage(string.format("1%% Low FPS:   %s", fps1LowStr))
    CHAT_ROUTER:AddSystemMessage(string.format("Latency:       %s  |  avg: %s  |  peak: %s",
        ColorStr(string.format("%d ms", math.floor(ping + 0.5)), PingColor(ping)),
        ColorStr(string.format("%d ms", math.floor(avg + 0.5)),  PingColor(avg)),
        ColorStr(string.format("%d ms", maxPing),                PingColor(maxPing))))
    CHAT_ROUTER:AddSystemMessage(string.format("Desync:        %s  (spikes: %d | dips: %d in last 60s)",
        ColorStr(string.format("%d ms", math.floor(desync + 0.5)), DesyncColor(desync)),
        spikes, sessionDips))
    CHAT_ROUTER:AddSystemMessage(string.format("Packet Loss:   %s",
        ColorStr(string.format("%.1f%%", pktLoss), PktLossColor(pktLoss))))
    CHAT_ROUTER:AddSystemMessage("-----------------------")
end

SLASH_COMMANDS["/statsfornerds"] = function(args)
    local cmd = args and string.lower(zo_strtrim(args)) or ""
    if cmd == "hide" then
        SNS.rootControl:SetHidden(true)
        SNS.saved.showOverlay = false
        CHAT_ROUTER:AddSystemMessage("[StatsForNerds] Overlay hidden. /statsfornerds show to restore.")
    elseif cmd == "show" then
        SNS.rootControl:SetHidden(false)
        SNS.saved.showOverlay = true
        CHAT_ROUTER:AddSystemMessage("[StatsForNerds] Overlay visible.")
    elseif cmd == "toggle" then
        local hidden = SNS.rootControl:IsHidden()
        SNS.rootControl:SetHidden(not hidden)
        SNS.saved.showOverlay = hidden
    else
        PrintAllStats()
    end
end

SLASH_COMMANDS["/sfn"] = function(args)
    local cmd = args and string.lower(zo_strtrim(args)) or ""
    if cmd == "hide" then
        SNS.rootControl:SetHidden(true)
        SNS.saved.showOverlay = false
        CHAT_ROUTER:AddSystemMessage("[StatsForNerds] Overlay hidden. /sfn show to restore.")
    elseif cmd == "show" then
        SNS.rootControl:SetHidden(false)
        SNS.saved.showOverlay = true
    elseif cmd == "reset" then
        SNS.rootControl:ClearAnchors()
        SNS.rootControl:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 30, 30)
        SNS.saved.x, SNS.saved.y = 30, 30
        CHAT_ROUTER:AddSystemMessage("[StatsForNerds] Position reset.")
    else
        PrintAllStats()
    end
end

SLASH_COMMANDS["/fps"] = function()
    local fps = GetFramerate()
    SayMetric("FPS", ColorStr(string.format("%.0f", fps), FpsColor(fps)))
end

SLASH_COMMANDS["/ping"] = function()
    local cur = GetLatency()
    local avg = Average(pingBuffer)
    SayMetric("Latency",
        ColorStr(string.format("%d ms (current)", cur), PingColor(cur)) ..
        "  |  avg: " ..
        ColorStr(string.format("%d ms", math.floor(avg + 0.5)), PingColor(avg)))
end

SLASH_COMMANDS["/desyncdata"] = function()
    local d = Jitter(pingBuffer)
    local s = CountSpikes(spikeBuffer)
    SayMetric("Desync",
        ColorStr(string.format("%d ms", math.floor(d + 0.5)), DesyncColor(d)) ..
        string.format("  (spikes: %d | dips: %d in 60s)", s, sessionDips))
end

SLASH_COMMANDS["/1percentlow"] = function()
    if #fpsBuffer < FPS_1LOW_MIN_SAMPLES then
        CHAT_ROUTER:AddSystemMessage(string.format(
            "[StatsForNerds] 1%%%% Low FPS: collecting... (%d/100 s)", #fpsBuffer))
        return
    end
    local v = PercentileLow(fpsBuffer, 0.01)
    SayMetric("1%% Low FPS", ColorStr(string.format("%.0f", v), FpsColor(v)))
end

SLASH_COMMANDS["/packetloss"] = function()
    local p = PacketLoss(pingBuffer)
    SayMetric("Packet Loss", ColorStr(string.format("%.1f%%", p), PktLossColor(p)))
end

SLASH_COMMANDS["/maxping"] = function()
    SayMetric("Peak Ping (session)", ColorStr(string.format("%d ms", maxPing), PingColor(maxPing)))
end
SLASH_COMMANDS["/sfnhelp"] = function()
    CHAT_ROUTER:AddSystemMessage("[StatsForNerds] Overlay: /sfn hide | show | reset  or  /statsfornerds hide| show| toggle")
    CHAT_ROUTER:AddSystemMessage("[StatsForNerds] Stats:   /fps  /ping  /desyncdata  /1percentlow  /packetloss  /statsfornerds (diagnostics) /sfn")
    CHAT_ROUTER:AddSystemMessage("[StatsForNerds] Settings panel: /sfnsettings  (LibAddonMenu)")
end

-- ─── Initialisation ─────────────────────────────────────────────────────────

function SNS:Initialize()
    self.saved = ZO_SavedVars:NewAccountWide(
        "StatsForNerdsSavedVars", 2,
        nil,
        DEFAULTS
    )
    -- One-time: existing saves still hold the old opaque background
    if not self.saved.transparentBgApplied then
        self.saved.bgAlpha = 0
        self.saved.transparentBgApplied = true
    end
    self:BuildUI()
    self:ApplyColors()
    self:RegisterSettings()
    zo_callLater(Tick, UPDATE_INTERVAL_MS)
end

EVENT_MANAGER:RegisterForEvent(
    SNS.name,
    EVENT_ADD_ON_LOADED,
    function(_, addonName)
        if addonName ~= SNS.name then return end
        SNS:Initialize()
    end
)
