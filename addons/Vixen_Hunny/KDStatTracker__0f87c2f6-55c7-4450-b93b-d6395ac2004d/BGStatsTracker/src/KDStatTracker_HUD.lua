-- KDStatTracker_HUD.lua
-- The on-screen tracker panel and the centre-screen kill announcer.
-- Fonts switch between the keyboard (Univers) and gamepad (Futura) faces
-- whenever the player changes input mode.

local KDST = KDStatTracker
local C = KDST.COLORS
local WM = WINDOW_MANAGER

local HUD = {}
KDST.HUD = HUD

local FONTS = {
    keyboard = { regular = "EsoUI/Common/Fonts/Univers57.otf", bold = "EsoUI/Common/Fonts/Univers67.otf" },
    gamepad  = { regular = "EsoUI/Common/Fonts/FTN57.otf",     bold = "EsoUI/Common/Fonts/FTN87.otf" },
}

function KDST.Font(size, bold, effect)
    local set = KDST.IsGamepadUI() and FONTS.gamepad or FONTS.keyboard
    return string.format("%s|%d|%s", bold and set.bold or set.regular, zo_round(size), effect or "soft-shadow-thick")
end

local PAD_X, PAD_Y, LINE_GAP, ACCENT_W = 12, 8, 2, 3

local function MakeLabel(name, parent)
    local label = WM:CreateControl(name, parent, CT_LABEL)
    label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    label:SetVerticalAlignment(TEXT_ALIGN_TOP)
    return label
end

-------------------------------------------------------------------------------
-- Tracker panel
-------------------------------------------------------------------------------
function HUD:Create()
    local s = KDST.settings
    local win = WM:CreateTopLevelWindow("KDStatTracker_HUD")
    win:SetClampedToScreen(true)
    win:SetMouseEnabled(true)
    win:SetDimensions(240, 80)
    win:SetHidden(true)
    self.control = win

    local bg = WM:CreateControl("KDStatTracker_HUDBG", win, CT_BACKDROP)
    bg:SetAnchorFill(win)
    bg:SetCenterColor(0.03, 0.03, 0.04, 0.72)
    bg:SetEdgeTexture("", 1, 1, 1)
    bg:SetEdgeColor(C.accent.r, C.accent.g, C.accent.b, 0.35)
    self.bg = bg

    local accent = WM:CreateControl("KDStatTracker_HUDAccent", win, CT_TEXTURE)
    accent:SetAnchor(TOPLEFT, win, TOPLEFT, 0, 0)
    accent:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, 0, 0)
    accent:SetWidth(ACCENT_W)
    accent:SetColor(C.accent:UnpackRGBA())
    self.accent = accent

    self.header  = MakeLabel("KDStatTracker_HUDHeader", win)
    self.line1   = MakeLabel("KDStatTracker_HUDLine1", win)
    self.line2   = MakeLabel("KDStatTracker_HUDLine2", win)
    self.detail1 = MakeLabel("KDStatTracker_HUDDetail1", win)
    self.detail2 = MakeLabel("KDStatTracker_HUDDetail2", win)
    self.lines = { self.header, self.line1, self.line2, self.detail1, self.detail2 }

    -- Drag to move; a click without moving opens the stats window.
    win:SetHandler("OnMouseDown", function(ctl, button)
        self.downLeft, self.downTop = ctl:GetLeft(), ctl:GetTop()
    end)
    win:SetHandler("OnMouseUp", function(ctl, button, upInside)
        if button ~= MOUSE_BUTTON_INDEX_LEFT or not upInside then return end
        local moved = self.downLeft and (math.abs(ctl:GetLeft() - self.downLeft) > 2 or math.abs(ctl:GetTop() - self.downTop) > 2)
        if not moved then KDST.OpenStatsDialog() end
    end)
    win:SetHandler("OnMoveStop", function(ctl)
        s.x, s.y = zo_round(ctl:GetLeft()), zo_round(ctl:GetTop())
    end)
    win:SetHandler("OnMouseEnter", function(ctl)
        InitializeTooltip(InformationTooltip, ctl, BOTTOM, 0, -6)
        SetTooltipText(InformationTooltip, KDST.displayName)
        InformationTooltip:AddLine(s.lockHUD and "Click to open stats." or "Click to open stats. Drag to move.", "", ZO_NORMAL_TEXT:UnpackRGB())
    end)
    win:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)

    self.defaultDrawTier = win:GetDrawTier()

    -- Only show on the plain HUD scenes; any menu (inventory, map, settings,
    -- crafting, dialogs...) swaps the scene and the tracker hides.
    if SCENE_MANAGER then
        SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, oldState, newState)
            if newState == SCENE_SHOWN or newState == SCENE_HIDDEN then self:UpdateVisibility() end
        end)
    end

    self:ApplyStyle()
end

-- Scenes where the tracker belongs. "hudui" is the HUD with the mouse cursor
-- shown; the siege scenes replace the HUD while operating siege weapons.
local HUD_SCENES = { "hud", "hudui", "siegeBar", "siegeBarUI" }

local function IsOnHUDScene()
    if not SCENE_MANAGER then return true end
    for _, name in ipairs(HUD_SCENES) do
        if SCENE_MANAGER:IsShowing(name) then return true end
    end
    return false
end

-- Temporary preview: show the HUD over menus for 3 seconds after a position
-- slider change (the timer restarts on every change), then hide it again.
local PREVIEW_MS = 3000
function HUD:Preview()
    self.previewTimed = true
    self:UpdateVisibility()
    EVENT_MANAGER:UnregisterForUpdate("KDStatTracker_HUDPreview")
    EVENT_MANAGER:RegisterForUpdate("KDStatTracker_HUDPreview", PREVIEW_MS, function()
        EVENT_MANAGER:UnregisterForUpdate("KDStatTracker_HUDPreview")
        self.previewTimed = nil
        self:UpdateVisibility()
    end)
end

function HUD:ApplyPosition()
    local s = KDST.settings
    self.control:ClearAnchors()
    self.control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, s.x or 40, s.y or 260)
end

function HUD:ApplyStyle()
    if not self.control then return end
    local s = KDST.settings
    local gamepadBoost = KDST.IsGamepadUI() and 4 or 0
    local size = (s.fontSize or 18) + gamepadBoost

    self.header:SetFont(KDST.Font(size * 0.62, true, "soft-shadow-thin"))
    self.line1:SetFont(KDST.Font(size, true))
    self.line2:SetFont(KDST.Font(size * 0.78, false))
    self.detail1:SetFont(KDST.Font(size * 0.72, false))
    self.detail2:SetFont(KDST.Font(size * 0.72, false))

    local r, g, b = ZO_ColorDef:New(KDST.ValidHex(s.fontColor)):UnpackRGB()
    for _, label in ipairs(self.lines) do label:SetColor(r, g, b, 1) end
    self.header:SetColor(C.accent:UnpackRGBA())

    self.control:SetScale(s.scale or 1)
    self.control:SetMovable(not s.lockHUD)
    self:ApplyPosition()
    self:UpdateVisibility()
    self:Refresh()
end

function HUD:UpdateVisibility()
    if not self.control then return end
    local s = KDST.settings
    local previewing = self.previewTimed
    local hidden
    if previewing then
        hidden = false
    else
        hidden = not s.showHUD or (s.hudPvPOnly and not KDST.IsInPvPArea()) or not IsOnHUDScene()
    end
    -- Draw above menus while previewing so the settings panel doesn't cover it.
    self.control:SetDrawTier(previewing and DT_HIGH or self.defaultDrawTier)
    self.control:SetHidden(hidden)
end

local function Label(text) return KDST.Color(C.muted, text) end

function HUD:Refresh()
    if not self.control then return end
    local s = KDST.settings
    local session, char = KDST.session, KDST.GetCharData()

    local k, d, mode
    if s.hudShowCharacter then
        k, d, mode = char.kills, char.deaths, "CHARACTER"
    else
        k, d, mode = session.kills, session.deaths, "SESSION"
    end
    if KDST.match then mode = mode .. "  |  IN MATCH" end

    self.header:SetText("KD TRACKER  |  " .. mode)
    self.line1:SetText(string.format("%s %s    %s %s    %s %s",
        Label("K"), KDST.Color(C.kill, k),
        Label("D"), KDST.Color(C.death, d),
        Label("K/D"), KDST.Color(C.ratio, KDST.Ratio(k, d))))

    local streakColor = session.streak >= 3 and C.gold or C.text
    local line2 = string.format("%s %s   %s %s", Label("Streak"), KDST.Color(streakColor, session.streak), Label("Best"), char.bestStreak or 0)
    if KDST.match then
        line2 = line2 .. string.format("   %s %s/%s", Label("Match"), KDST.Color(C.kill, KDST.match.kills), KDST.Color(C.death, KDST.match.deaths))
    end
    self.line2:SetText(line2)

    local showDetails = s.hudShowDetails
    if showDetails then
        local fav = KDST.SortedCounts(char.killSources, "abilityName")[1]
        local nem = KDST.SortedCounts(char.deathSources, "abilityName")[1]
        self.detail1:SetText(string.format("%s %s", Label("Favorite"), fav and string.format("%s (%d)", fav.name, fav.count) or "-"))
        self.detail2:SetText(string.format("%s %s", Label("Nemesis"), nem and string.format("%s (%d)", nem.name, nem.count) or "-"))
    end
    self.detail1:SetHidden(not showDetails)
    self.detail2:SetHidden(not showDetails)

    self:Layout()
end

function HUD:Layout()
    local x = ACCENT_W + PAD_X
    local y = PAD_Y
    local width = 0
    for _, label in ipairs(self.lines) do
        if not label:IsHidden() then
            label:ClearAnchors()
            label:SetAnchor(TOPLEFT, self.control, TOPLEFT, x, y)
            local w, h = label:GetTextDimensions()
            width = math.max(width, w)
            y = y + h + LINE_GAP
        end
    end
    self.control:SetDimensions(x + width + PAD_X, y - LINE_GAP + PAD_Y)
end

function HUD:ResetPosition()
    local s = KDST.settings
    s.x, s.y = KDST.settingDefaults.x, KDST.settingDefaults.y
    self:ApplyPosition()
end

-------------------------------------------------------------------------------
-- Announcer banner
-------------------------------------------------------------------------------
function HUD:CreateBanner()
    local banner = WM:CreateTopLevelWindow("KDStatTracker_Banner")
    banner:SetDimensions(900, 130)
    banner:SetAnchor(CENTER, GuiRoot, CENTER, 0, -230)
    banner:SetMouseEnabled(false)
    banner:SetHidden(true)
    banner:SetDrawTier(DT_HIGH)

    local title = WM:CreateControl("KDStatTracker_BannerTitle", banner, CT_LABEL)
    title:SetAnchor(CENTER, banner, CENTER, 0, -14)
    title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    local sub = WM:CreateControl("KDStatTracker_BannerSub", banner, CT_LABEL)
    sub:SetAnchor(TOP, title, BOTTOM, 0, 2)
    sub:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    local timeline = ANIMATION_MANAGER:CreateTimeline()
    local fadeIn = timeline:InsertAnimation(ANIMATION_ALPHA, banner, 0)
    fadeIn:SetAlphaValues(0, 1)
    fadeIn:SetDuration(140)
    local pop = timeline:InsertAnimation(ANIMATION_SCALE, banner, 0)
    pop:SetScaleValues(1.35, 1)
    pop:SetDuration(220)
    local fadeOut = timeline:InsertAnimation(ANIMATION_ALPHA, banner, 1700)
    fadeOut:SetAlphaValues(1, 0)
    fadeOut:SetDuration(500)
    timeline:SetHandler("OnStop", function() banner:SetHidden(true) end)

    self.banner, self.bannerTitle, self.bannerSub, self.bannerTimeline = banner, title, sub, timeline
end

function HUD:ShowBanner(text, colorHex, subText, sound)
    if not KDST.settings.showBanners then return end
    if not self.banner then self:CreateBanner() end

    local gp = KDST.IsGamepadUI()
    self.bannerTitle:SetFont(KDST.Font(gp and 56 or 48, true, "thick-outline"))
    self.bannerSub:SetFont(KDST.Font(gp and 26 or 22, false))
    self.bannerTitle:SetText(text)
    self.bannerTitle:SetColor(ZO_ColorDef:New(colorHex or "FFD45C"):UnpackRGBA())
    self.bannerSub:SetText(subText or "")
    self.bannerSub:SetColor(C.text:UnpackRGBA())

    self.bannerTimeline:Stop()
    self.banner:SetAlpha(0)
    self.banner:SetHidden(false)
    self.bannerTimeline:PlayFromStart()

    if sound and KDST.settings.playSounds and SOUNDS and SOUNDS[sound] then
        PlaySound(SOUNDS[sound])
    end
end

-------------------------------------------------------------------------------
-- Callback wiring
-------------------------------------------------------------------------------
function HUD:OnKill(streak, multi, victim)
    local multiName = multi >= 2 and (KDST.MULTI_KILLS[multi] or KDST.MULTI_KILL_MAX_NAME) or nil
    local streakDef = KDST.STREAKS[streak]
    if multiName then
        self:ShowBanner(multiName, "FFD45C", streakDef and streakDef.name or (victim and ("Killed " .. victim)), "ACHIEVEMENT_AWARDED")
    elseif streakDef then
        self:ShowBanner(streakDef.name, streakDef.color, string.format("%d kills without dying", streak), "ACHIEVEMENT_AWARDED")
    end
end

function HUD:OnDeath(endedStreak, killer)
    if endedStreak >= 3 then
        self:ShowBanner("Streak Ended", "E06A5F", string.format("%d-kill streak ended by %s", endedStreak, killer or "Unknown"), "NEGATIVE_CLICK")
    end
end

function HUD:OnMatchEnded(entry)
    local kd = KDST.Ratio(entry.kills, entry.deaths)
    self:ShowBanner("Match Complete", "C5A86E",
        string.format("%s   %d kills  /  %d deaths   K/D %s", KDST.GetMatchTypeName(entry.matchType), entry.kills, entry.deaths, kd))
end

function HUD:Initialize()
    self:Create()
    local cb = KDST.callbacks
    cb:RegisterCallback("StatsChanged", function() self:Refresh() end)
    cb:RegisterCallback("Kill", function(...) self:OnKill(...) end)
    cb:RegisterCallback("Death", function(...) self:OnDeath(...) end)
    cb:RegisterCallback("MatchEnded", function(entry) self:OnMatchEnded(entry) end)
    cb:RegisterCallback("ZoneChanged", function() self:UpdateVisibility(); self:Refresh() end)
    cb:RegisterCallback("PlatformChanged", function() self:ApplyStyle() end)
end
