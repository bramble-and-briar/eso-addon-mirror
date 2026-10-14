-- Groupbound_HUD.lua : on screen while you play, in the game's quiet look (layout A):
--   small board  (optional, off by default) the five groups that fit you best, docked like the
--                game's quest tracker: no frame, see-through black, the game's fonts and colors
--   alert        (picked 2026-10-12: B "small notice top right") a new group for content you
--                watch slides in at the top right, stays 7 s, slides out; click = open it
--   applicant    someone applied to your listing: the same notice, click = your applicants
--   role switch  a member of your group switched role after joining (Groupbound_Watch)
-- Never during fights (the alert waits until you're out of combat, then shows the newest).
-- Inside dungeons / trials / arenas (setting quietInside) the small board and new-group alerts
-- stay away; applicant notices still come (you're leading a listing).

local G = Groupbound
local C = G.COLOR
local L = G.L
local Anim = G.Anim
local W = G.W
local Board = G.Board
local HUD = {}
G.HUD = HUD

local HUD_W = 340
local LINES = 5
local LINE_H = 24
local hud, notice, fragment
local lastAlertId, waitingAlert, waitingApplicant
local noticeClick          -- what a click on the notice opens

local function CreateBoard()
    hud = WINDOW_MANAGER:CreateTopLevelWindow("Groupbound_HUD")
    hud:SetDimensions(HUD_W, 34 + LINES * LINE_H)
    hud:SetMouseEnabled(true)
    hud:SetMovable(true)
    hud:SetClampedToScreen(true)
    local x, y = G.sv.hud.x, G.sv.hud.y
    if x and y then hud:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y) else hud:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -20, 420) end
    hud:SetHandler("OnMouseDown", function() hud.pressX, hud.pressY = hud:GetLeft(), hud:GetTop() end)
    hud:SetHandler("OnMoveStop", function()
        G.sv.hud.x, G.sv.hud.y = hud:GetLeft(), hud:GetTop()
    end)
    local bg = W.Tex(hud, nil, nil, nil, C.panel, 0.45)
    bg:SetAnchorFill(hud)
    hud.title = W.Label(hud, "ZoFontWinH5", C.selected, "")
    hud.title:SetAnchor(TOPLEFT, hud, TOPLEFT, 10, 6)
    hud.lines = {}
    for i = 1, LINES do
        local line = W.Label(hud, "ZoFontGame", C.normal, "")
        line:SetAnchor(TOPLEFT, hud, TOPLEFT, 10, 30 + (i - 1) * LINE_H)
        line:SetWidth(HUD_W - 20)
        hud.lines[i] = line
    end
    hud.empty = W.Label(hud, "ZoFontGameSmall", C.dim, L("HUD_EMPTY"))
    hud.empty:SetAnchor(TOPLEFT, hud, TOPLEFT, 10, 32)
    hud.empty:SetWidth(HUD_W - 20)
    -- (clicks found by position: the lines are labels inside the movable window)
    hud:SetHandler("OnMouseUp", function(_, button, upInside)
        local moved = hud.pressX and (math.abs(hud:GetLeft() - hud.pressX) > 3 or math.abs(hud:GetTop() - hud.pressY) > 3)
        hud.pressX, hud.pressY = nil, nil
        if not upInside or moved then return end
        if button == MOUSE_BUTTON_INDEX_RIGHT then
            ClearMenu()
            AddMenuItem(L("HUD_HIDE"), function() G.ToggleHud() end)
            ShowMenu(hud)
            return
        end
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        for _, line in ipairs(hud.lines) do
            if line.id and G.IsOver(line, 2) then
                PlaySound(SOUNDS.DEFAULT_CLICK)
                G.UI.ShowEntry(line.id)
                return
            end
        end
        G.UI.Toggle()
    end)
    hud:SetHandler("OnMouseEnter", function()
        InitializeTooltip(InformationTooltip, hud, RIGHT, -8, 0, LEFT)
        SetTooltipText(InformationTooltip, L("HUD_TT"))
    end)
    hud:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
    fragment = G.HudFragment(hud)
end

function HUD.Refresh()
    if not hud then return end
    local show = G.sv.hud.shown and not G.Quiet()
    G.ShowOnHud(fragment, show)
    if not show then return end
    hud.title:SetText(zo_strupper(L("HUD_TITLE", G.RoleName(G.MyRole()))))
    local n = 0
    for _, e in ipairs(Board.ForMeList(LINES)) do
        n = n + 1
        local line = hud.lines[n]
        line.id = e.id
        line:SetText(Board.ColoredTag(e) .. "  " .. Board.Readable(Board.Title(e)))
        line:SetHidden(false)
    end
    for i = n + 1, LINES do
        hud.lines[i].id = nil
        hud.lines[i]:SetHidden(true)
    end
    hud.empty:SetHidden(n > 0)
    HUD.Fit()
    -- (wrapped text heights settle a moment later)
    G.Later(HUD.Fit, 50, "HUD")
end

-- lines one under the other, each as tall as its (wrapped) text: nothing cut off
function HUD.Fit()
    if not hud then return end
    local y = 30
    local any = false
    for _, line in ipairs(hud.lines) do
        if not line:IsHidden() then
            any = true
            line:ClearAnchors()
            line:SetAnchor(TOPLEFT, hud, TOPLEFT, 10, y)
            y = y + math.max(LINE_H, (line:GetTextHeight() or 0) + 6)
        end
    end
    if not any then y = y + LINE_H end
    hud:SetHeight(y + 4)
end

-- ---------------------------------------------------------------------------
-- Alert: a small notice at the top right (slides in from the right edge, fades out)

local NOTICE_W = 320
local function CreateNotice()
    notice = WINDOW_MANAGER:CreateTopLevelWindow("Groupbound_Notice")
    notice:SetDimensions(NOTICE_W, 62)
    notice:SetDrawTier(DT_HIGH)
    notice:SetMouseEnabled(true)
    notice:SetHidden(true)
    local bg = W.Tex(notice, nil, nil, nil, C.panel, 0.65)
    bg:SetAnchorFill(notice)
    local edge = W.Tex(notice, nil, 2, nil, C.normal, 0.8)
    edge:SetAnchor(TOPLEFT, notice, TOPLEFT, 0, 0)
    edge:SetAnchor(BOTTOMLEFT, notice, BOTTOMLEFT, 0, 0)
    notice.icon = W.Tex(notice, G.LOGO, 36, 36)
    notice.icon:SetAnchor(LEFT, notice, LEFT, 12, 0)
    notice.title = W.Label(notice, "ZoFontGameBold", C.selected, "")
    notice.title:SetAnchor(TOPLEFT, notice, TOPLEFT, 58, 8)
    notice.title:SetWidth(NOTICE_W - 70)
    notice.line = W.Label(notice, "ZoFontGameSmall", C.normal, "")
    notice.line:SetAnchor(TOPLEFT, notice.title, BOTTOMLEFT, 0, 2)
    notice.line:SetWidth(NOTICE_W - 70)
    notice:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT then
            PlaySound(SOUNDS.DEFAULT_CLICK)
            notice:SetHidden(true)
            if noticeClick then noticeClick() end
        end
    end)
    notice:SetHandler("OnMouseEnter", function()
        if not noticeClick then return end
        InitializeTooltip(InformationTooltip, notice, BOTTOM, 0, 6, TOP)
        SetTooltipText(InformationTooltip, L("ALERT_CLICK"))
    end)
    notice:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
end

local function PlaceNotice(offsetX)
    notice:ClearAnchors()
    notice:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -20 + offsetX, 110)
end

local token = 0
local function ShowNoticeText(title, line, onClick)
    if not notice then CreateNotice() end
    notice.title:SetText(title)
    notice.line:SetText(line)
    -- as tall as its texts (nothing cut off)
    local function Fit()
        notice:SetHeight(math.max(62, 8 + (notice.title:GetTextHeight() or 0) + 2 + (notice.line:GetTextHeight() or 0) + 10))
    end
    Fit()
    G.Later(Fit, 50, "Notice")
    noticeClick = onClick
    notice:SetHidden(false)
    token = token + 1
    local mine = token
    if G.sv.sound then PlaySound(SOUNDS.GROUP_FINDER_REFRESH_SEARCH or SOUNDS.DEFAULT_CLICK) end
    Anim.Run("Groupbound_Notice", 300, Anim.Out, function(p)
        PlaceNotice((1 - p) * 40)
        notice:SetAlpha(p)
    end)
    G.Later(function()
        if mine ~= token then return end
        Anim.Run("Groupbound_Notice", 400, Anim.In, function(p)
            PlaceNotice(p * 40)
            notice:SetAlpha(1 - p)
        end, function()
            if mine == token then notice:SetHidden(true) end
        end)
    end, 7000, "Notice")
end

-- any short message in the same notice (onClick optional: a click just closes it)
function HUD.Notice(title, line, onClick)
    ShowNoticeText(title, line, onClick)
end

local function ShowNotice(e)
    local need = e.open and L("ALERT_NEEDS", G.RoleName(G.MyRole())) or L("ALERT_ROLES_UNKNOWN")
    local id = e.id
    ShowNoticeText(L("ALERT_TITLE", Board.ColoredTag(e)), need .. "  ·  " .. Board.SourceText(e), function() G.UI.ShowEntry(id) end)
end

-- someone applied to your listing
local function ShowApplicantNotice(a)
    local char = a.char ~= "" and zo_strformat("<<1>>", a.char) or a.account
    local cp = (a.cp or 0) > 0 and L("APPS_CP", a.cp) or L("HEADER_LEVEL", a.level or 0)
    ShowNoticeText(L("APPS_NOTICE_TITLE", char), L("APPS_NOTICE_LINE", G.RoleName(a.role), cp), G.UI.ShowApplicants)
end

function HUD.Applicant(a)
    if not a or not G.sv.toast then return end
    -- the applicants page is open: you see it already
    if G.UI.IsShown() and G.sv.view == "applicants" then return end
    if IsUnitInCombat("player") then
        waitingApplicant = a
        return
    end
    ShowApplicantNotice(a)
end

function HUD.Alert(e)
    if not e then return end
    lastAlertId = e.id
    if not G.sv.toast or G.Quiet() then return end
    if IsUnitInCombat("player") then
        waitingAlert = e
        return
    end
    ShowNotice(e)
end

-- keybind: open the newest alert
function HUD.OpenLastAlert()
    if notice then notice:SetHidden(true) end
    if lastAlertId then G.UI.ShowEntry(lastAlertId) else G.UI.Show() end
end

function HUD.Init()
    CreateBoard()
    HUD.Refresh()
    G.callbacks:RegisterCallback("BoardChanged", HUD.Refresh)
    G.callbacks:RegisterCallback("SettingsChanged", HUD.Refresh)
    G.callbacks:RegisterCallback("Alert", HUD.Alert)
    G.callbacks:RegisterCallback("ApplicantsChanged", HUD.Applicant)
    G.EM:RegisterForEvent("Groupbound_HUDCombat", EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
        if inCombat then return end
        if waitingApplicant then
            local a = waitingApplicant
            waitingApplicant = nil
            if G.sv.toast then ShowApplicantNotice(a) end
        elseif waitingAlert then
            local e = Board.Find(waitingAlert.id)
            waitingAlert = nil
            if e and G.sv.toast and not G.Quiet() then ShowNotice(e) end
        end
    end)
    -- loading screens: entering or leaving a dungeon / trial (quietInside)
    G.EM:RegisterForEvent("Groupbound_HUDZone", EVENT_PLAYER_ACTIVATED, HUD.Refresh)
    G.callbacks:RegisterCallback("PositionsReset", function()
        hud:ClearAnchors()
        hud:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -20, 420)
    end)
end
