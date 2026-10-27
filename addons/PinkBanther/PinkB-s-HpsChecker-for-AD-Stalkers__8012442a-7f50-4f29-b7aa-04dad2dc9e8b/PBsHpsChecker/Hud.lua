PBsHpsChecker = PBsHpsChecker or {}
local ADDON = PBsHpsChecker

---------------------------------------------------------------------------------------------------
-- The HUD meter
--
-- A small box that is up while the player is healing and for a few seconds after, with the fight's
-- numbers:
--
--     HPS  8,420                              the fight's HPS
--     last 10 s  9,100                        and over the last ten seconds
--     healed  456,789   3:12   14 players     amount, time spent healing, how many were healed
--     party 62%  outside 31%  self 7%         who the amount went to
--     your share of party healing  72%        of what party members received from every healer, how
--                                             much was yours; 100% while no other healer's heal has reached the add-on
--     your share of party's healing  72%      of what party members received from every healer, how much
--                                             was yours; only when other healers' heals reach the add-on
--
-- It takes no input, so on console it cannot take a gamepad button from the game. It is drawn only
-- while the HUD (or the HUD with the cursor free) is the scene, through "StateChange" callbacks
-- registered beside the client's own -- nothing of the client's is hooked. While this add-on's
-- settings panel is open it is shown with sample numbers instead, so its place can be adjusted.
---------------------------------------------------------------------------------------------------

local hud = { visible = false, sceneShown = false, preview = false, nextUpdate = 0 }
ADDON.hud = hud

local NAME = "PBsHpsCheckerHud"
-- The box is as wide as its longest line needs, between these.
local MIN_WIDTH = 480
local MAX_WIDTH = 1000
-- A box whose size is given in pixels is kept between these (and the width at most as wide as the screen).
local MIN_BOX_WIDTH = 120
local MIN_BOX_HEIGHT = 60
local PADDING = 14
local UPDATE_MS = 250
local LINE_PADDING = 4
local PINK = { 1, 0.41, 0.71 }
local GREY = { 0.75, 0.75, 0.75 }
local WHITE = { 1, 1, 1 }

-- The sizes, smallest to largest: a pair of named gamepad fonts each, for the big HPS line and for the
-- rows under it. Only fonts the console UI is known to have loaded are used (they are the ones PB's
-- KillLog and this add-on's statistics screen use; a face nothing else draws with has to be built
-- on use, and that has crashed a PS5 before), so the size goes in steps and stops at 34, not in a
-- smooth scale. 4 is what the box has always been.
local SIZES = {
    { big = "ZoFontGamepadBold22", row = "ZoFontGamepad20" },
    { big = "ZoFontGamepadBold25", row = "ZoFontGamepad20" },
    { big = "ZoFontGamepadBold27", row = "ZoFontGamepad22" },
    { big = "ZoFontGamepadBold34", row = "ZoFontGamepad22" },
    { big = "ZoFontGamepadBold34", row = "ZoFontGamepad25" },
    { big = "ZoFontGamepadBold34", row = "ZoFontGamepad27" },
    { big = "ZoFontGamepadBold34", row = "ZoFontGamepad34" },
}
local DEFAULT_SIZE = 4
hud.NUM_SIZES = #SIZES
hud.DEFAULT_SIZE = DEFAULT_SIZE

local SAMPLE = {
    hps = 8420, recent = 9100, heal = 456789, secs = 54, people = 14,
    groupShare = 0.62, otherShare = 0.31, selfShare = 0.07, ptShare = 0.72,
}

local records = ADDON.records

local function Now()
    return GetFrameTimeMilliseconds()
end

local function L(id)
    return GetString(id)
end

-- Font, size and place are set by Layout, which runs again when the size is changed.
local function Label(parent, suffix)
    local label = WINDOW_MANAGER:CreateControl(NAME .. suffix, parent, CT_LABEL)
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    label:SetMaxLineCount(1)
    return label
end

-- The size chosen in the settings, 1 to NUM_SIZES; a missing or wild value is the standard size.
function hud:Size()
    local size = math.floor(tonumber(ADDON.sv and ADDON.sv.hudSize) or DEFAULT_SIZE)
    return math.max(1, math.min(#SIZES, size))
end

function hud:Fonts()
    local size = SIZES[self:Size()]
    return size.big, size.row
end

-- Wide enough for the longest each line can get, as the client measures it (a line that is too wide
-- for its label ends in "..." from the right). A client that does not say gives the minimum.
function hud:ChooseWidth(bigFont, rowFont)
    local widest = 0
    local function Take(font, text)
        local width = ADDON.MeasureText(font, text)
        if width and width > widest then
            widest = width
        end
    end
    Take(bigFont, string.format(L(SI_PBSHPS_HUD_HPS), "99,999"))
    Take(rowFont, string.format(L(SI_PBSHPS_HUD_RECENT), records.RING_SECONDS, "99,999"))
    Take(rowFont, string.format(L(SI_PBSHPS_HUD_TOTAL), "999,999,999", "9:59:59", 250))
    Take(rowFont, string.format(L(SI_PBSHPS_HUD_SHARE), 100, 100, 100))
    Take(rowFont, string.format(L(SI_PBSHPS_HUD_PT_SHARE), "100%"))
    return math.min(MAX_WIDTH, math.max(MIN_WIDTH, math.ceil(widest) + PADDING * 2))
end

-- Fonts, sizes and places of the five lines and the box, from the size chosen. Run when the box is
-- built and again whenever the size is changed: a control cannot be built twice, so the ones there are
-- are set again.
function hud:Layout()
    local top = self.control
    local bigFont, rowFont = self:Fonts()
    local bigHeight = ADDON.MeasureFont(bigFont) + LINE_PADDING
    local rowHeight = ADDON.MeasureFont(rowFont) + LINE_PADDING
    -- What the text needs: as wide as its longest line, as tall as four lines, or five when the player's
    -- share of what party members received is known.
    self.autoWidth = self:ChooseWidth(bigFont, rowFont)
    self.heightBase = PADDING * 2 + bigHeight + rowHeight * 3
    self.heightWithShare = self.heightBase + rowHeight
    -- What is used: that, or the size given in pixels.
    self.width = self:BoxWidth()
    local innerWidth = self.width - PADDING * 2
    top:SetDimensions(self.width, self:BoxHeight())

    local y = PADDING
    local lines = {
        { self.big, bigFont, bigHeight },
        { self.recent, rowFont, rowHeight },
        { self.total, rowFont, rowHeight },
        { self.share, rowFont, rowHeight },
        { self.partyShare, rowFont, rowHeight },
    }
    for _, line in ipairs(lines) do
        local label, font, height = line[1], line[2], line[3]
        label:SetFont(font)
        label:SetDimensions(innerWidth, height)
        label:ClearAnchors()
        label:SetAnchor(TOPLEFT, top, TOPLEFT, PADDING, y)
        y = y + height
    end
end

function hud:Create()
    if self.control then
        return self.control
    end
    if not WINDOW_MANAGER or not GuiRoot then
        return nil
    end

    local top = WINDOW_MANAGER:CreateTopLevelWindow(NAME)
    top:SetHidden(true)
    top:SetMouseEnabled(false)
    top:SetMovable(false)
    -- Above the settings panel, which the preview is drawn over.
    top:SetDrawLayer(DL_OVERLAY)
    top:SetDrawTier(DT_MEDIUM)
    self.control = top

    local fill = WINDOW_MANAGER:CreateControl(NAME .. "Fill", top, CT_TEXTURE)
    fill:SetColor(0, 0, 0, 0.6)
    fill:SetAnchorFill(top)

    self.big = Label(top, "Big")
    self.recent = Label(top, "Recent")
    self.total = Label(top, "Total")
    self.share = Label(top, "Share")
    self.partyShare = Label(top, "PartyShare")
    self.partyShare:SetHidden(true)
    self.partyShareShown = false
    self:Layout()

    top:SetHandler("OnUpdate", function()
        local now = Now()
        if now < self.nextUpdate then
            return
        end
        self.nextUpdate = now + UPDATE_MS
        self:Update(now)
    end)
    self:ApplyLayout()
    return top
end

-- The box's width and height in pixels. With "set the size in pixels" off they are what the text
-- needs. With it on they are what the settings say, whatever the text needs: a line that is too wide
-- ends in "..." from the right, and lines past the bottom are drawn below the box.
function hud:BoxWidth()
    local sv = ADDON.sv
    if not (sv and sv.hudCustomSize) then
        return self.autoWidth
    end
    local screen = GuiRoot and GuiRoot:GetWidth() or MAX_WIDTH
    return math.max(MIN_BOX_WIDTH, math.min(math.floor(screen), math.floor(tonumber(sv.hudWidth) or ADDON.defaults.hudWidth)))
end

function hud:BoxHeight()
    local sv = ADDON.sv
    if not (sv and sv.hudCustomSize) then
        return self.partyShareShown and self.heightWithShare or self.heightBase
    end
    local screen = GuiRoot and GuiRoot:GetHeight() or 1080
    return math.max(MIN_BOX_HEIGHT, math.min(math.floor(screen), math.floor(tonumber(sv.hudHeight) or ADDON.defaults.hudHeight)))
end

-- Switching "set the size in pixels" on: start from the size the box has now, so that it does not
-- jump, with room for all five lines. Rounded up to the slider's step.
function hud:StartCustomSize(step)
    if not self:Create() then
        return
    end
    step = step or 5
    ADDON.sv.hudWidth = math.ceil(self.autoWidth / step) * step
    ADDON.sv.hudHeight = math.ceil(self.heightWithShare / step) * step
end

-- The size was changed in the settings: set the box out again and draw it. Nothing to do before the
-- box exists; it is built at the new size.
function hud:ApplySize()
    if not self.control then
        return
    end
    self:Layout()
    self:Refresh()
end

-- Not built until the box is wanted, so that nothing is created (and no font asked for) at load.
function hud:ApplyLayout()
    local control = self.control
    if not control then
        return
    end
    control:ClearAnchors()
    control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, ADDON.sv.hudLeft, ADDON.sv.hudTop)
end

---------------------------------------------------------------------------------------------------
-- What is drawn
---------------------------------------------------------------------------------------------------

-- Three whole-number shares that add up to 100.
local function Shares(group, other, self)
    local g = math.floor((group or 0) * 100 + 0.5)
    local o = math.floor((other or 0) * 100 + 0.5)
    return g, o, math.max(0, 100 - g - o)
end

-- data: hps, recent (nil once the fight is over), heal, secs, people, and the three shares.
function hud:Draw(data, ended)
    local color = ended and GREY or PINK
    self.big:SetColor(color[1], color[2], color[3], 1)
    self.big:SetText(string.format(L(SI_PBSHPS_HUD_HPS), records.Commas(data.hps)))

    local recentColor = ended and GREY or WHITE
    self.recent:SetColor(recentColor[1], recentColor[2], recentColor[3], 1)
    if ended then
        self.recent:SetText(L(SI_PBSHPS_HUD_ENDED))
    else
        self.recent:SetText(string.format(L(SI_PBSHPS_HUD_RECENT), records.RING_SECONDS, records.Commas(data.recent or 0)))
    end

    self.total:SetColor(recentColor[1], recentColor[2], recentColor[3], 1)
    self.total:SetText(string.format(L(SI_PBSHPS_HUD_TOTAL), records.Commas(data.heal), records.Duration(data.secs), data.people))

    self.share:SetColor(recentColor[1], recentColor[2], recentColor[3], 1)
    self.share:SetText(string.format(L(SI_PBSHPS_HUD_SHARE), Shares(data.groupShare, data.otherShare, data.selfShare)))

    -- The fifth line, and the box grown to hold it, only while there is a share to show.
    local showShare = data.ptShare ~= nil
    if showShare ~= self.partyShareShown then
        self.partyShareShown = showShare
        self.partyShare:SetHidden(not showShare)
        self.control:SetDimensions(self.width, self:BoxHeight())
    end
    if showShare then
        self.partyShare:SetColor(recentColor[1], recentColor[2], recentColor[3], 1)
        self.partyShare:SetText(string.format(L(SI_PBSHPS_HUD_PT_SHARE), records.Percent(data.ptShare, 0)))
    end
end

local function FightData(fight, now, ended)
    local heal = math.max(1, fight.heal)
    return {
        hps = records:FightHps(fight),
        recent = not ended and records:RecentHps(fight, now) or nil,
        heal = fight.heal,
        secs = fight.secs,
        people = fight.people,
        groupShare = fight.group / heal,
        otherShare = fight.other / heal,
        selfShare = fight.self / heal,
        ptShare = records.PartyShare(fight.group, fight.recvOthers),
    }
end

---------------------------------------------------------------------------------------------------
-- Showing
---------------------------------------------------------------------------------------------------

-- The fight to draw: the one going on, or the last one for as long as the hold time lasts.
function hud:Subject(now)
    local fight = records.fight
    if fight then
        return fight, false
    end
    local last = records.lastFight
    local hold = (ADDON.sv.hudHoldSec or 10) * 1000
    if last and last.closedMs and now - last.closedMs <= hold then
        return last, true
    end
    return nil
end

function hud:Wanted(now)
    local sv = ADDON.sv
    if not sv.enabled or not sv.hud then
        return false
    end
    if self.preview then
        return true
    end
    return self.sceneShown and self:Subject(now) ~= nil
end

function hud:SetVisible(visible)
    self.visible = visible
    if self.control then
        self.control:SetHidden(not visible)
    end
end

function hud:Update(now)
    if not self:Wanted(now) then
        self:SetVisible(false)
        return
    end
    local fight, ended = self:Subject(now)
    -- The preview is for placing the box: a fight that has just ended is not worth showing then,
    -- only one that is going on.
    if self.preview and ended then
        fight = nil
    end
    if fight then
        self:Draw(FightData(fight, now, ended), ended)
    else
        self:Draw(SAMPLE, false)
    end
end

-- Shows or hides to match the state of things. Cheap, and only touches the control on a change.
function hud:Refresh()
    local now = Now()
    if self:Wanted(now) then
        if not self:Create() then
            return
        end
        self:Update(now)
        self:SetVisible(true)
    elseif self.visible then
        self:SetVisible(false)
    end
end

-- Called for every heal that is counted: the box comes up with the first one of a fight.
function hud:Poke()
    if not self.visible then
        self:Refresh()
    end
end

-- The settings panel was opened (true) or closed (false).
function hud:OnPanelOpen(open)
    self.preview = open and true or false
    self:Refresh()
end

local function OnSceneStateChange()
    hud.sceneShown = (HUD_SCENE and HUD_SCENE:IsShowing()) or (HUD_UI_SCENE and HUD_UI_SCENE:IsShowing()) or false
    hud:Refresh()
end

function hud:Initialize()
    if HUD_SCENE then
        HUD_SCENE:RegisterCallback("StateChange", OnSceneStateChange)
    end
    if HUD_UI_SCENE then
        HUD_UI_SCENE:RegisterCallback("StateChange", OnSceneStateChange)
    end
    OnSceneStateChange()
end
