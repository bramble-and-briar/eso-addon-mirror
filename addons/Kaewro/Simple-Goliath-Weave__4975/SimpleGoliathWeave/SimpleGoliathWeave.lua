--------------------------------------------------------------------------------
-- SimpleGoliathWeave
-- Shows when you can light attack again after casting Goliath (Bone Goliath
-- Transformation or one of its morphs). The transform animation is longer than
-- the global cooldown, so a light attack pressed too early gets swallowed.
--
-- Timing works like a GCD cast bar:
--   * the timer starts from the game's own global cooldown info (not just from
--     the key press), so it stays in sync with the server
--   * the red part at the end of the bar is your ping: when the bar reaches the
--     red, press light attack and it arrives just as the animation ends
--
-- Credits: the ping zone and GCD-sync timing idea comes from Combat Metronome
-- (by Darianopolis and barny). No code from it is included here.
--------------------------------------------------------------------------------

local ADDON = "SimpleGoliathWeave"

local SGW = {}
SGW.name = ADDON
SGW.version = "1.0.1"

local EM = EVENT_MANAGER
local WM = WINDOW_MANAGER

-- Ability IDs for the three Goliath ultimates. Detection uses these IDs only,
-- so it works on every client language.
local KNOWN_IDS = {
    [115001] = true, -- Bone Goliath Transformation
    [118664] = true, -- Pummeling Goliath (confirmed in game)
    [118279] = true, -- Ravenous Goliath (confirmed in game)
    [118314] = true, -- Ravenous Goliath (older listed ID, kept just in case)
}

local ULT_SLOT = (ACTION_BAR_ULTIMATE_SLOT_INDEX or 7) + 1
local FALLBACK_ICON = "/esoui/art/icons/icon_missing.dds"
local SYNC_WINDOW_MS = 500      -- how long after the press we accept the GCD update for syncing
local SYNC_MAX_SHIFT_MS = 300   -- ignore GCD sync results that move the start further than this

local COLOR_MOVE = { 0.95, 0.75, 0.15, 0.80 }

local defaults = {
    enabled      = true,
    animMs       = 1320,   -- Goliath animation lock, without ping (measured in game)
    adjustMs     = 25,     -- extra safety margin added to the animation
    showPing     = true,   -- red ping zone at the end of the bar
    maxPing      = 150,    -- cap for the ping zone
    readyHoldMs  = 500,    -- how long the bar stays after it ends
    sound        = false,
    width        = 305,
    height       = 43,
    fontSize     = 20,
    offsetX      = 0,
    offsetY      = 140,
    colorBar     = { 0.85, 0.75, 0.20, 0.95 },
    colorPing    = { 0.85, 0.15, 0.15, 0.95 },
    colorReady   = { 0.20, 0.90, 0.30, 0.95 },
}

local function Say(msg)
    d("|c66ccff[SGW]|r " .. msg)
end

local function Now()
    return GetFrameTimeMilliseconds()
end

--------------------------------------------------------------------------------
-- Timing helpers (same idea as a GCD tracker)
--------------------------------------------------------------------------------

-- Ping used for the red zone, capped so a lag spike doesn't wreck the bar.
function SGW:GetPing()
    if not self.sv.showPing then return 0 end
    return math.min(GetLatency() or 0, self.sv.maxPing)
end

-- Remaining / total of the global cooldown, read from the action slots.
local function GetGCD()
    for i = 3, 8 do
        local remaining, duration, isGlobal = GetSlotCooldownInfo(i)
        if isGlobal and duration and duration > 0 then
            return remaining, duration
        end
    end
    return 0, 0
end

function SGW:AnimLength()
    return self.sv.animMs + self.sv.adjustMs
end

--------------------------------------------------------------------------------
-- Detection
--------------------------------------------------------------------------------
local function OnSlotUsed(_, slotNum)
    if slotNum ~= ULT_SLOT then return end
    local id = GetSlotBoundId(slotNum, GetActiveHotbarCategory())
    if KNOWN_IDS[id] then
        SGW:Start(GetAbilityIcon(id))
    end
end

-- Re-sync the start with the game's global cooldown, the same way GCD trackers
-- do: start = now + remaining - duration. The cooldown event is only registered
-- for the short moment right after a Goliath cast.
local function StopSync()
    SGW.syncPending = false
    EM:UnregisterForEvent(ADDON .. "Cooldowns", EVENT_ACTION_UPDATE_COOLDOWNS)
end

local function OnCooldownsUpdated()
    local now = Now()
    if now - SGW.pressTime > SYNC_WINDOW_MS then
        StopSync()
        return
    end
    local remaining, duration = GetGCD()
    if remaining <= 0 then return end
    StopSync()

    local gcdStart = now + remaining - duration
    if math.abs(gcdStart - SGW.pressTime) <= SYNC_MAX_SHIFT_MS then
        SGW.start = gcdStart
    end
end

local function StartSync()
    SGW.syncPending = true
    EM:RegisterForEvent(ADDON .. "Cooldowns", EVENT_ACTION_UPDATE_COOLDOWNS, OnCooldownsUpdated)
end

local function OnPlayerDead()
    SGW:Hide()
end

-- Only keep events registered while the addon is enabled.
local function CheckEventsNeeded()
    EM:UnregisterForEvent(ADDON .. "SlotUsed", EVENT_ACTION_SLOT_ABILITY_USED)
    EM:UnregisterForEvent(ADDON .. "Dead", EVENT_PLAYER_DEAD)
    StopSync()

    if SGW.sv.enabled then
        EM:RegisterForEvent(ADDON .. "SlotUsed", EVENT_ACTION_SLOT_ABILITY_USED, OnSlotUsed)
        EM:RegisterForEvent(ADDON .. "Dead", EVENT_PLAYER_DEAD, OnPlayerDead)
    else
        SGW:Hide()
    end
end

function SGW:SetEnabled(enabled)
    self.sv.enabled = enabled
    CheckEventsNeeded()
end

--------------------------------------------------------------------------------
-- Display: a cast bar that shrinks toward a red ping zone at the right end
--------------------------------------------------------------------------------
function SGW:CreateUI()
    local top = WM:CreateTopLevelWindow(ADDON .. "Top")
    top:SetHidden(true)
    top:SetClampedToScreen(true)
    top:SetMouseEnabled(false)
    top:SetMovable(false)
    top:SetDrawTier(DT_HIGH)

    local icon = WM:CreateControl("$(parent)Icon", top, CT_TEXTURE)
    icon:SetTexture(FALLBACK_ICON)

    local barBg = WM:CreateControl("$(parent)BarBg", top, CT_TEXTURE)
    barBg:SetColor(0, 0, 0, 0.60)

    -- the red ping zone is drawn on top of the bar so it is always visible
    local fill = WM:CreateControl("$(parent)Fill", top, CT_TEXTURE)
    fill:SetDrawLevel(1)
    local ping = WM:CreateControl("$(parent)Ping", top, CT_TEXTURE)
    ping:SetDrawLevel(2)

    local label = WM:CreateControl("$(parent)Label", top, CT_LABEL)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetDrawLevel(3)

    top:SetHandler("OnMoveStop", function()
        local cx, cy = top:GetCenter()
        local rx, ry = GuiRoot:GetCenter()
        self.sv.offsetX = math.floor(cx - rx)
        self.sv.offsetY = math.floor(cy - ry)
        self:ApplyPosition()
    end)

    self.top, self.icon, self.barBg, self.ping, self.fill, self.label = top, icon, barBg, ping, fill, label
    self.updateFn = function() self:OnUpdate() end
    self.state = "idle"

    self:ApplyLayout()
    self:ApplyPosition()
end

function SGW:ApplyPosition()
    self.top:ClearAnchors()
    self.top:SetAnchor(CENTER, GuiRoot, CENTER, self.sv.offsetX, self.sv.offsetY)
end

function SGW:ApplyLayout()
    local sv = self.sv
    local w, h = sv.width, sv.height

    self.top:SetDimensions(w, h)

    self.icon:ClearAnchors()
    self.icon:SetAnchor(LEFT, self.top, LEFT, 0, 0)
    self.icon:SetDimensions(h, h)

    self.barBg:ClearAnchors()
    self.barBg:SetAnchor(TOPLEFT, self.icon, TOPRIGHT, 4, 0)
    self.barBg:SetAnchor(BOTTOMRIGHT, self.top, BOTTOMRIGHT, 0, 0)

    self.barW = math.max(10, w - h - 4)

    -- both the ping zone and the progress are anchored to the right end
    self.ping:ClearAnchors()
    self.ping:SetAnchor(RIGHT, self.barBg, RIGHT, 0, 0)
    self.ping:SetDimensions(0, h)
    self.ping:SetColor(unpack(sv.colorPing))

    self.fill:ClearAnchors()
    self.fill:SetAnchor(RIGHT, self.barBg, RIGHT, 0, 0)
    self.fill:SetDimensions(0, h)
    self.fill:SetColor(unpack(sv.colorBar))

    self.label:ClearAnchors()
    self.label:SetAnchor(CENTER, self.barBg, CENTER, 0, 0)
    self.label:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thick", sv.fontSize))
end

function SGW:Start(iconPath)
    local now = Now()
    self.pressTime = now
    self.start = now
    StartSync()
    self.state = "wait"
    self.readySoundPlayed = false

    self.icon:SetTexture((iconPath and iconPath ~= "") and iconPath or FALLBACK_ICON)
    self.fill:SetColor(unpack(self.sv.colorBar))
    self.label:SetColor(1, 1, 1, 1)
    self.top:SetHidden(false)
    self.top:SetHandler("OnUpdate", self.updateFn)
    self:OnUpdate()
end

function SGW:ShowMoveHint()
    self.state = "idle"
    self.top:SetHandler("OnUpdate", nil)
    self.ping:SetWidth(0)
    self.fill:SetColor(unpack(COLOR_MOVE))
    self.fill:SetWidth(self.barW)
    self.label:SetColor(1, 1, 1, 1)
    self.label:SetText("Drag to move")
    self.top:SetHidden(false)
end

function SGW:Hide()
    self.state = "idle"
    StopSync()
    self.top:SetHandler("OnUpdate", nil)
    if self.sv.locked then
        self.top:SetHidden(true)
    else
        self:ShowMoveHint()
    end
end

function SGW:OnUpdate()
    local now = Now()
    local anim = self:AnimLength()
    local ping = self:GetPing()
    local total = anim + ping              -- whole bar
    local elapsed = now - self.start
    local remaining = total - elapsed      -- time until the bar is empty

    if self.state == "wait" or self.state == "ready" then
        if remaining > 0 then
            local pingW = self.barW * (ping / total)
            self.ping:SetWidth(pingW)
            self.fill:SetWidth(math.max(0, self.barW * (remaining / total)))

            -- reached the red = press light attack now
            if elapsed >= anim then
                if self.state ~= "ready" then
                    self.state = "ready"
                    self.fill:SetColor(unpack(self.sv.colorReady))
                    self.label:SetColor(unpack(self.sv.colorReady))
                    self.label:SetText("LA NOW")
                    if self.sv.sound and not self.readySoundPlayed then
                        self.readySoundPlayed = true
                        PlaySound(SOUNDS.ABILITY_ULTIMATE_READY or SOUNDS.DEFAULT_CLICK)
                    end
                end
            else
                self.label:SetText(string.format("WAIT  %.1f", (anim - elapsed) / 1000))
            end
            return
        end

        -- bar is empty: keep "LA NOW" up for a moment, then hide
        self.state = "done"
        self.hideAt = now + self.sv.readyHoldMs
        self.ping:SetWidth(0)
        self.fill:SetColor(unpack(self.sv.colorReady))
        self.fill:SetWidth(self.barW)
        self.label:SetColor(1, 1, 1, 1)
        self.label:SetText("LA NOW")

    elseif self.state == "done" then
        if now >= self.hideAt then
            self:Hide()
        end
    end
end

function SGW:SetLocked(locked)
    self.sv.locked = locked
    self.top:SetMouseEnabled(not locked)
    self.top:SetMovable(not locked)
    if not locked then
        self:ShowMoveHint()
    elseif self.state == "idle" then
        self.top:SetHidden(true)
    end
end

function SGW:Preview()
    self:Start(GetAbilityIcon(115001))
    StopSync()
end

--------------------------------------------------------------------------------
-- Settings (LibAddonMenu-2.0)
--------------------------------------------------------------------------------
local function ColorOption(name, key)
    local sv = SGW.sv
    return {
        type = "colorpicker",
        name = name,
        getFunc = function() return unpack(sv[key]) end,
        setFunc = function(r, g, b, a) sv[key] = { r, g, b, a }; SGW:ApplyLayout() end,
        default = { r = defaults[key][1], g = defaults[key][2], b = defaults[key][3], a = defaults[key][4] },
    }
end

function SGW:BuildSettings()
    local LAM = LibAddonMenu2
    local sv = self.sv

    local panelData = {
        type = "panel",
        name = "SimpleGoliathWeave",
        displayName = "SimpleGoliathWeave",
        author = "Kaewro",
        version = self.version,
        registerForRefresh = true,
        registerForDefaults = true,
    }
    self.panel = LAM:RegisterAddonPanel(ADDON .. "Panel", panelData)

    local options = {
        {
            type = "checkbox",
            name = "Enabled",
            getFunc = function() return sv.enabled end,
            setFunc = function(v) self:SetEnabled(v) end,
            default = defaults.enabled,
        },
        { type = "header", name = "Timing" },
        {
            type = "description",
            text = "When the bar reaches the red part, press light attack. The red part is your ping.",
        },
        {
            type = "slider",
            name = "Animation length (ms, without ping)",
            tooltip = "How long the Goliath animation lasts, without ping. This is the same for every player, so you normally don't need to change it.",
            min = 500, max = 4000, step = 10,
            getFunc = function() return sv.animMs end,
            setFunc = function(v) sv.animMs = v end,
            default = defaults.animMs,
        },
        {
            type = "slider",
            name = "Safety margin (ms)",
            tooltip = "Added on top of the animation. Raise it if you still miss light attacks, lower it if \"LA NOW\" feels late.",
            min = -100, max = 200, step = 5,
            getFunc = function() return sv.adjustMs end,
            setFunc = function(v) sv.adjustMs = v end,
            default = defaults.adjustMs,
        },
        {
            type = "checkbox",
            name = "Show ping (red zone)",
            getFunc = function() return sv.showPing end,
            setFunc = function(v) sv.showPing = v end,
            default = defaults.showPing,
        },
        {
            type = "slider",
            name = "Max ping (ms)",
            tooltip = "The red zone never gets bigger than this, so lag spikes don't make it huge.",
            min = 0, max = 500, step = 10,
            getFunc = function() return sv.maxPing end,
            setFunc = function(v) sv.maxPing = v end,
            disabled = function() return not sv.showPing end,
            default = defaults.maxPing,
        },
        { type = "header", name = "Look" },
        {
            type = "checkbox",
            name = "Sound when ready",
            getFunc = function() return sv.sound end,
            setFunc = function(v) sv.sound = v end,
            default = defaults.sound,
        },
        {
            type = "slider",
            name = "Width",
            min = 120, max = 600, step = 5,
            getFunc = function() return sv.width end,
            setFunc = function(v) sv.width = v; self:ApplyLayout() end,
            default = defaults.width,
        },
        {
            type = "slider",
            name = "Height",
            min = 10, max = 100, step = 1,
            getFunc = function() return sv.height end,
            setFunc = function(v) sv.height = v; self:ApplyLayout() end,
            default = defaults.height,
        },
        {
            type = "slider",
            name = "Text size",
            min = 10, max = 48, step = 1,
            getFunc = function() return sv.fontSize end,
            setFunc = function(v) sv.fontSize = v; self:ApplyLayout() end,
            default = defaults.fontSize,
        },
        ColorOption("Bar colour", "colorBar"),
        ColorOption("Ping colour", "colorPing"),
        ColorOption("Ready colour", "colorReady"),
        {
            type = "button",
            name = "Preview",
            func = function() self:Preview() end,
        },
        {
            type = "button",
            name = "Unlock / Lock",
            func = function() self:SetLocked(not sv.locked) end,
        },
    }
    LAM:RegisterOptionControls(ADDON .. "Panel", options)
end

--------------------------------------------------------------------------------
-- Slash commands
--------------------------------------------------------------------------------
-- /sgw       open the settings
-- /sgw on    enable
-- /sgw off   disable
-- /sgw unlock / lock   move the bar
local function OnSlash(text)
    local cmd = zo_strlower((text or ""):match("^%s*(%S*)") or "")

    if cmd == "on" then
        SGW:SetEnabled(true)
        Say("Enabled.")
    elseif cmd == "off" then
        SGW:SetEnabled(false)
        Say("Disabled.")
    elseif cmd == "unlock" then
        SGW:SetLocked(false)
        Say("Unlocked. Drag the bar, then /sgw lock.")
    elseif cmd == "lock" then
        SGW:SetLocked(true)
        Say("Locked.")
    else
        LibAddonMenu2:OpenToPanel(SGW.panel)
    end
end

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------
local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON then return end
    EM:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)

    -- account-wide, but separate per server (EU / NA / PTS)
    SGW.sv = ZO_SavedVars:NewAccountWide("SimpleGoliathWeaveSV", 1, nil, defaults, GetWorldName())
    SGW.sv.locked = true -- always start locked

    SGW:CreateUI()
    SGW:BuildSettings()

    CheckEventsNeeded()

    SLASH_COMMANDS["/sgw"] = OnSlash
end

EM:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
