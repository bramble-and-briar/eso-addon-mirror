-- Battle report: the story of one match on one screen, opened when you leave a
-- finished battleground (setting), from the records (A / double-click) or
-- /sbr report. Three tabs:
--   Overview    result banner, match balance (0-100), team cards, MVP, titles
--   Timeline    score over time, the damage race, kills per minute (momentum)
--   Your match  what you gained (AP, XP, Champion Points, AvA rank, medals), your
--               title and your profile against the best in the match
-- Drawn with the game's own battleground art: team emblems, win / loss banners,
-- team scoreboard backgrounds and highlight strips, capture-bar fills for every
-- bar and chart, and the currency / experience / champion / rank / medal icons.
-- Same window on PC (mouse) and console (controller), laid out for a 1920 x 1080
-- canvas and scaled down on smaller ones. Data: Data/Report.lua.
local SBR = ScoreboardRemastered
local RP = { tab = "overview", keyboardSceneName = "scoreboardRemasteredReportKeyboard", gamepadSceneName = "scoreboardRemasteredReport" }
SBR.ReportUI = RP

local WM = WINDOW_MANAGER
local DESIGN_W, DESIGN_H = 1920, 1080
local PANEL_W, PANEL_H = 1560, 880
local PAD = 40
local BODY_TOP = 262
local TABS = { "overview", "timeline", "you" }
local TAB_LABEL = { overview = "Overview", timeline = "Timeline", you = "Your match" }

local RESULT = {
    won = { "Victory", { 0.50, 0.90, 0.52 } }, lost = { "Defeat", { 0.95, 0.42, 0.38 } },
    tie = { "Draw", { 0.90, 0.84, 0.58 } }, left = { "Left early", { 0.66, 0.66, 0.66 } },
    unknown = { "Unfinished", { 0.66, 0.66, 0.66 } },
}
local DIM, WHITE, GOLD, NORMAL = { 0.60, 0.60, 0.62 }, { 1, 1, 1 }, { 0.95, 0.82, 0.48 }, { 0.80, 0.78, 0.64 }

---------------------------------------------------------------------------
-- the game's art (paths checked against the ESO UI source, API 101051)
---------------------------------------------------------------------------
local ART = "EsoUI/Art/Battlegrounds/"
local function TeamArtColor(id) return SBR.TeamArtColor(id) end
local function TeamEmblem(id) return SBR.TeamArt(id, "emblemLarge") end
local function TeamPoint(id) return ART .. "battlegroundsCaptureBar_point_" .. TeamArtColor(id) .. ".dds" end

-- Icons are never drawn larger than their file (that's what looked pixelated): the
-- gamepad versions are the larger files and are used wherever an icon is big.
local ICON = {
    overview = "EsoUI/Art/Campaign/Gamepad/gp_overview_menuIcon_scoring.dds",
    timeline = "EsoUI/Art/Battlegrounds/Gamepad/gp_battlegrounds_tabIcon_competitive.dds",
    you = "EsoUI/Art/Champion/Gamepad/gp_champion_icon.dds",
    kills = "EsoUI/Art/Battlegrounds/Gamepad/gp_battlegrounds_tabIcon_deathmatch.dds",
    deaths = "EsoUI/Art/DeathRecap/deathRecap_killingBlow_icon.dds",
    assists = "EsoUI/Art/Campaign/Gamepad/gp_overview_menuIcon_bonus.dds",
    damage = "EsoUI/Art/Battlegrounds/Gamepad/gp_battlegrounds_tabIcon_competitive.dds",
    healing = "EsoUI/Art/Champion/champion_points_health_icon.dds",
    score = "EsoUI/Art/Campaign/Gamepad/gp_overview_menuIcon_scoring.dds",
    medals = "EsoUI/Art/Achievements/achievements_reward_earned.dds",
    xp = "EsoUI/Art/Icons/Icon_Experience.dds",
    cp = "EsoUI/Art/Champion/Gamepad/gp_champion_icon.dds",
    shield = "EsoUI/Art/Crafting/Gamepad/gp_crafting_enchanting_glyphSlot_shield.dds",
    glow = "EsoUI/Art/Miscellaneous/lensflare_burst_512.dds",
    frame = "EsoUI/Art/Miscellaneous/progressbar_frame.dds",
    frameBG = "EsoUI/Art/Miscellaneous/progressbar_frame_bg.dds",
    divider = "EsoUI/Art/Miscellaneous/horizontalDivider.dds",
    header = ART .. "BattlegroundRoundRecapHeader.dds",
    headerLoss = ART .. "BattlegroundRoundRecapHeader_loss.dds",
}
-- a title's icon (Data/Report.lua titles)
local TITLE_ICON = {
    Slayer = ICON.kills, Vanguard = ICON.damage, Lifeline = ICON.healing, Wingman = ICON.assists,
    ["Objective runner"] = "EsoUI/Art/Battlegrounds/Gamepad/gp_battlegrounds_tabIcon_flaggames.dds",
    Medalist = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_achievements.dds", Unbreakable = ICON.shield,
}
local function TitleIcon(title, team)
    local i = TITLE_ICON[title]
    if i == "point" then return TeamPoint(team) end
    return i
end
local function APIcon()
    return SBR.API("GetCurrencyGamepadIcon", CURT_ALLIANCE_POINTS) or SBR.API("GetCurrencyKeyboardIcon", CURT_ALLIANCE_POINTS)
        or "EsoUI/Art/currency/gamepad/gp_gold.dds"
end
-- a player's class icon: the large (gamepad) file when the class is known
local function ClassIcon(p)
    return (p.classId and SBR.API("ZO_GetGamepadClassIcon", p.classId)) or p.classIcon
end

local function Num(v) return type(v) == "number" and v or 0 end
local function N(v) return v == nil and "-" or SBR.FormatNumber(v) end

---------------------------------------------------------------------------
-- control helpers
---------------------------------------------------------------------------
local count = 0
local function Name(kind) count = count + 1 return "SBR_RP_" .. kind .. count end

local function Font(...)
    for i = 1, select("#", ...) do
        local f = select(i, ...)
        if _G[f] ~= nil then return f end
    end
    return "ZoFontGame"
end
local F
local function Fonts()
    if F then return F end
    F = {
        giant = Font("ZoFontGamepadBold61", "ZoFontGamepadBold54", "ZoFontGamepad61", "ZoFontWinH1"),
        huge = Font("ZoFontGamepadBold54", "ZoFontGamepadBold48", "ZoFontGamepad42", "ZoFontWinH1"),
        title = Font("ZoFontGamepadBold34", "ZoFontGamepad34", "ZoFontWinH2"),
        big = Font("ZoFontGamepadBold27", "ZoFontGamepad27", "ZoFontWinH3"),
        text = Font("ZoFontGamepad27", "ZoFontGamepad25", "ZoFontGame"),
        small = Font("ZoFontGamepad22", "ZoFontGame"),
        tiny = Font("ZoFontGamepad18", "ZoFontGamepad20", "ZoFontGameSmall"),
    }
    return F
end

local function Label(parent, font, rgb, align)
    local l = WM:CreateControl(Name("L"), parent, CT_LABEL)
    l:SetFont(font)
    l:SetColor(rgb and rgb[1] or 1, rgb and rgb[2] or 1, rgb and rgb[3] or 1, 1)
    l:SetHorizontalAlignment(align or TEXT_ALIGN_LEFT)
    l:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    l:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    return l
end

local function Upper(l)
    if MODIFY_TEXT_TYPE_UPPERCASE and l.SetModifyTextType then l:SetModifyTextType(MODIFY_TEXT_TYPE_UPPERCASE) end
    return l
end

local function Tex(parent, r, g, b, a, path)
    local t = WM:CreateControl(Name("T"), parent, CT_TEXTURE)
    if path then t:SetTexture(path) end
    t:SetColor(r, g, b, a)
    return t
end

local function Backdrop(parent)
    for _, v in ipairs({ "ZO_DefaultBackdrop_Gamepad", "ZO_DefaultBackdrop" }) do
        local ok, bd = pcall(WM.CreateControlFromVirtual, WM, Name("BG"), parent, v)
        if ok and bd then bd:SetAnchorFill(parent) return bd end
    end
    local t = Tex(parent, 0.04, 0.05, 0.06, 0.94)
    t:SetAnchorFill(parent)
    return t
end

local function Paint(c, rgb, a) c:SetColor(rgb[1], rgb[2], rgb[3], a or 1) end

local function TeamRGB(match, id)
    local t = match and match.teams and match.teams[id]
    return { SBR.HexToRGB(t and t.color or "BBBBBB") }
end

-- a reusable pool of child controls under `parent`, reset before each render
local function Pool(parent, make)
    local pool = { items = {}, used = 0 }
    function pool:Get()
        self.used = self.used + 1
        local c = self.items[self.used]
        if not c then
            c = make(parent)
            self.items[self.used] = c
        end
        c:SetHidden(false)
        c:ClearAnchors()
        return c
    end
    function pool:Reset()
        for i = 1, #self.items do self.items[i]:SetHidden(true) end
        self.used = 0
    end
    return pool
end

---------------------------------------------------------------------------
-- construction
---------------------------------------------------------------------------
function RP:Create()
    if self.control then return end
    local f = Fonts()
    local tlw = WM:CreateTopLevelWindow("ScoreboardRemasteredReport")
    self.control = tlw
    tlw:SetHidden(true)
    tlw:SetAnchorFill(GuiRoot)
    tlw:SetDrawLayer(DL_OVERLAY)
    tlw:SetDrawTier(DT_HIGH)
    local dim = Tex(tlw, 0, 0, 0, 0.68)
    dim:SetAnchorFill(tlw)

    local frame = WM:CreateControl(Name("Frame"), tlw, CT_CONTROL)
    frame:SetDimensions(DESIGN_W, DESIGN_H)
    frame:SetAnchor(CENTER, tlw, CENTER, 0, 0)
    self.frame = frame

    local panel = WM:CreateControl(Name("Panel"), frame, CT_CONTROL)
    panel:SetDimensions(PANEL_W, PANEL_H)
    panel:SetAnchor(TOPLEFT, frame, TOPLEFT, (DESIGN_W - PANEL_W) / 2, 40)
    panel:SetMouseEnabled(true)
    Backdrop(panel)
    self.panel = panel

    -- header: your team's win / loss banner across the top, the round-recap header
    -- art behind the result, your team's emblem, result, map and details
    -- gradients, not stretched art: they stay sharp at any size
    self.bannerArt = Tex(panel, 1, 1, 1, 1)
    self.bannerArt:SetDimensions(PANEL_W - 4, 190)
    self.bannerArt:SetAnchor(TOPLEFT, panel, TOPLEFT, 2, 2)
    self.bannerEdge = Tex(panel, 1, 1, 1, 1)
    self.bannerEdge:SetDimensions(PANEL_W - 4, 4)
    self.bannerEdge:SetAnchor(TOPLEFT, panel, TOPLEFT, 2, 2)
    self.headerArt = Tex(panel, 1, 1, 1, 1)
    self.headerArt:SetDimensions(760, 72)
    self.headerArt:SetAnchor(TOPLEFT, panel, TOPLEFT, PAD + 120, 26)
    self.emblemGlow = Tex(panel, 1, 1, 1, 0.55, ICON.glow)
    self.emblemGlow:SetDimensions(210, 210)
    self.emblemGlow:SetAnchor(CENTER, panel, TOPLEFT, PAD + 56, 92)
    self.emblem = Tex(panel, 1, 1, 1, 1)
    self.emblem:SetDimensions(112, 112)
    self.emblem:SetAnchor(CENTER, panel, TOPLEFT, PAD + 56, 92)
    self.result = Upper(Label(panel, f.giant))
    self.result:SetDimensions(640, 66)
    self.result:SetAnchor(TOPLEFT, panel, TOPLEFT, PAD + 132, 30)
    self.map = Label(panel, f.title, WHITE)
    self.map:SetDimensions(800, 40)
    self.map:SetAnchor(TOPLEFT, self.result, BOTTOMLEFT, 0, 0)
    self.details = Label(panel, f.small, NORMAL)
    self.details:SetDimensions(800, 28)
    self.details:SetAnchor(TOPLEFT, self.map, BOTTOMLEFT, 0, 2)

    -- match balance: the two leading teams' emblems either side of a framed bar
    local bx = PANEL_W - PAD - 470
    self.balanceCaption = Upper(Label(panel, f.small, DIM, TEXT_ALIGN_CENTER))
    self.balanceCaption:SetDimensions(470, 24)
    self.balanceCaption:SetAnchor(TOPLEFT, panel, TOPLEFT, bx, 30)
    self.balanceCaption:SetText("Match balance")
    self.balanceValue = Label(panel, f.giant, WHITE, TEXT_ALIGN_CENTER)
    self.balanceValue:SetDimensions(160, 66)
    self.balanceValue:SetAnchor(TOP, self.balanceCaption, BOTTOM, 0, -2)
    self.balanceText = Upper(Label(panel, f.big, WHITE, TEXT_ALIGN_CENTER))
    self.balanceText:SetDimensions(300, 30)
    self.balanceText:SetAnchor(TOP, self.balanceValue, BOTTOM, 0, -4)
    self.balanceLeft = Tex(panel, 1, 1, 1, 1)
    self.balanceLeft:SetDimensions(64, 64)
    self.balanceLeft:SetAnchor(TOPLEFT, panel, TOPLEFT, bx, 70)
    self.balanceRight = Tex(panel, 1, 1, 1, 1)
    self.balanceRight:SetDimensions(64, 64)
    self.balanceRight:SetAnchor(TOPRIGHT, panel, TOPLEFT, bx + 470, 70)
    self.balanceBorder = Tex(panel, 1, 1, 1, 0.18)
    self.balanceBorder:SetDimensions(470, 16)
    self.balanceBorder:SetAnchor(TOPLEFT, panel, TOPLEFT, bx, 156)
    self.balanceTrack = Tex(panel, 0, 0, 0, 0.75)
    self.balanceTrack:SetDimensions(468, 14)
    self.balanceTrack:SetAnchor(CENTER, self.balanceBorder, CENTER, 0, 0)
    self.balanceFill = Tex(panel, 1, 1, 1, 1)
    self.balanceFill:SetAnchor(LEFT, self.balanceTrack, LEFT, 1, 0)
    self.balanceFill:SetHeight(12)
    self.balanceShine = Tex(panel, 1, 1, 1, 0.22)
    self.balanceShine:SetAnchor(TOPLEFT, self.balanceFill, TOPLEFT, 0, 0)
    self.balanceShine:SetHeight(3)

    -- tabs with icons
    self.tabs = {}
    local x = PAD
    for _, key in ipairs(TABS) do
        local tab = WM:CreateControl(Name("Tab"), panel, CT_CONTROL)
        tab:SetDimensions(250, 46)
        tab:SetAnchor(TOPLEFT, panel, TOPLEFT, x, BODY_TOP - 64)
        tab:SetMouseEnabled(true)
        tab:SetHandler("OnMouseUp", function(_, button, upInside) if upInside then RP:SetTab(key) end end)
        tab.icon = Tex(tab, 1, 1, 1, 1, ICON[key])
        tab.icon:SetDimensions(36, 36)
        tab.icon:SetAnchor(LEFT, tab, LEFT, 8, 0)
        tab.label = Upper(Label(tab, f.big, NORMAL))
        tab.label:SetText(TAB_LABEL[key])
        tab.label:SetDimensions(190, 40)
        tab.label:SetAnchor(LEFT, tab.icon, RIGHT, 10, 0)
        tab.glow = Tex(tab, 1, 1, 1, 0.55, ICON.glow)
        tab.glow:SetDimensions(220, 60)
        tab.glow:SetAnchor(BOTTOM, tab, BOTTOM, 0, 22)
        tab.underline = Tex(tab, 1, 1, 1, 1, ICON.divider)
        tab.underline:SetDimensions(230, 6)
        tab.underline:SetAnchor(TOP, tab, BOTTOM, 0, 0)
        self.tabs[key] = tab
        x = x + 270
    end
    local line = Tex(panel, 1, 1, 1, 0.6, ICON.divider)
    line:SetDimensions(PANEL_W - PAD * 2, 6)
    line:SetAnchor(TOPLEFT, panel, TOPLEFT, PAD, BODY_TOP - 12)

    -- body: everything per tab comes from these pools
    local body = WM:CreateControl(Name("Body"), panel, CT_CONTROL)
    body:SetDimensions(PANEL_W - PAD * 2, PANEL_H - BODY_TOP - PAD)
    body:SetAnchor(TOPLEFT, panel, TOPLEFT, PAD, BODY_TOP)
    self.body = body
    self.boxes = Pool(body, function(p) return Tex(p, 1, 1, 1, 1) end)        -- solid colour
    self.arts = Pool(body, function(p) return Tex(p, 1, 1, 1, 1) end)         -- textures
    self.texts = Pool(body, function(p) return Label(p, f.text) end)
end

-- the label pool hands out one font; set it per use
local function Text(self, font, rgb, align, text, w, h)
    local l = self.texts:Get()
    l:SetFont(font)
    Paint(l, rgb or WHITE)
    l:SetHorizontalAlignment(align or TEXT_ALIGN_LEFT)
    l:SetDimensions(w or 300, h or 30)
    l:SetText(text or "")
    if l.SetModifyTextType and MODIFY_TEXT_TYPE_NONE then l:SetModifyTextType(MODIFY_TEXT_TYPE_NONE) end
    return l
end
local function Caption(self, f, text, w)
    return Upper(Text(self, f.small, DIM, TEXT_ALIGN_LEFT, text, w or 600, 26))
end

local function Box(self, rgb, a, w, h)
    local b = self.boxes:Get()
    local c = { rgb[1], rgb[2], rgb[3], a or 1 }
    SBR.Gradient(b, c, c) -- also clears a gradient left from the box's last use
    b:SetDimensions(math.max(0, w), math.max(0, h))
    return b
end

-- a gradient box: from colour a ({ r, g, b, alpha }) to b, left to right or top to bottom
local function Grad(self, a, b, w, h, horizontal)
    local t = self.boxes:Get()
    SBR.Gradient(t, a, b, horizontal)
    t:SetDimensions(math.max(0, w), math.max(0, h))
    return t
end

-- Keyboard-size icon files are small: drawing one bigger than this makes it blurry,
-- so it's kept at this size (the gamepad files, glows and game icons are larger).
local SMALL_ICON_MAX = 40
local function IsLargeFile(path)
    return path:find("/Gamepad/", 1, true) or path:find("lensflare", 1, true) or not path:find("^EsoUI/Art/")
        or path:find("/Icons/", 1, true) or path:find("[Mm]edal")
end
local function Art(self, path, w, h, rgb, a)
    local t = self.arts:Get()
    path = path or ICON.score
    if not IsLargeFile(path) and (w > SMALL_ICON_MAX or h > SMALL_ICON_MAX) then
        local k = SMALL_ICON_MAX / math.max(w, h)
        w, h = math.floor(w * k), math.floor(h * k)
    end
    t:SetTexture(path)
    t:SetColor(rgb and rgb[1] or 1, rgb and rgb[2] or 1, rgb and rgb[3] or 1, a or 1)
    t:SetDimensions(math.max(0, w), math.max(0, h))
    return t
end

-- A percentage bar drawn with plain shapes (no stretched art): a dark track with a
-- thin border, a gradient fill in the given colour from 0 to `share` of the width,
-- a highlight along its top, and quarter tick marks so it reads as a scale.
local function Bar(self, anchorTo, point, relPoint, x, y, w, share, rgb)
    local h = 22
    local border = Box(self, { 1, 1, 1 }, 0.18, w, h)
    border:SetAnchor(point, anchorTo, relPoint, x, y)
    local track = Box(self, { 0, 0, 0 }, 0.75, w - 2, h - 2)
    track:SetAnchor(CENTER, border, CENTER, 0, 0)
    share = math.max(0, math.min(1, Num(share)))
    if share > 0 then
        local fw = math.max(2, (w - 4) * share)
        local fill = Grad(self, { rgb[1] * 0.6, rgb[2] * 0.6, rgb[3] * 0.6, 1 }, { rgb[1], rgb[2], rgb[3], 1 }, fw, h - 4, true)
        fill:SetAnchor(LEFT, track, LEFT, 1, 0)
        local shine = Box(self, { 1, 1, 1 }, 0.22, fw, 3)
        shine:SetAnchor(TOPLEFT, fill, TOPLEFT, 0, 0)
    end
    for q = 1, 3 do
        local tick = Box(self, { 1, 1, 1 }, 0.16, 1, h - 6)
        tick:SetAnchor(LEFT, track, LEFT, math.floor((w - 2) * q / 4), 0)
    end
    return border
end

-- icon + value (+ caption under it)
local function Stat(self, f, anchorTo, x, y, icon, value, caption, valueRgb)
    local ic = Art(self, icon, 34, 34)
    ic:SetAnchor(TOPLEFT, anchorTo, TOPLEFT, x, y)
    local v = Text(self, f.big, valueRgb or WHITE, TEXT_ALIGN_LEFT, value, 150, 30)
    v:SetAnchor(LEFT, ic, RIGHT, 8, -6)
    if caption then
        local c = Upper(Text(self, f.tiny, DIM, TEXT_ALIGN_LEFT, caption, 150, 20))
        c:SetAnchor(TOPLEFT, v, BOTTOMLEFT, 0, -4)
    end
    return ic
end

---------------------------------------------------------------------------
-- rendering
---------------------------------------------------------------------------
local function SortedTeams(m)
    local ids = {}
    for id in pairs(m.teams or {}) do ids[#ids + 1] = id end
    table.sort(ids, function(a, b) return Num(m.teams[a].score) > Num(m.teams[b].score) end)
    return ids
end

function RP:Render()
    local m = self.match
    if not m then return end
    local f = Fonts()
    local res = RESULT[m.result] or RESULT.unknown
    local mine = m.localTeam or SortedTeams(m)[1]
    local won = m.result == "won" or m.result == "tie"
    local teamRgb = TeamRGB(m, mine)
    SBR.Gradient(self.bannerArt, { teamRgb[1], teamRgb[2], teamRgb[3], won and 0.32 or 0.2 }, { teamRgb[1], teamRgb[2], teamRgb[3], 0 })
    self.bannerEdge:SetColor(teamRgb[1], teamRgb[2], teamRgb[3], 0.9)
    SBR.Gradient(self.headerArt, { res[2][1], res[2][2], res[2][3], 0.22 }, { res[2][1], res[2][2], res[2][3], 0 }, true)
    self.emblem:SetTexture(TeamEmblem(mine))
    Paint(self.emblemGlow, res[2], 0.45)
    Paint(self.result, res[2])
    self.result:SetText(res[1])
    self.map:SetText(m.name or m.zoneName or "Battleground")
    self.details:SetText(string.format("%s  ·  %s  ·  %s", m.gameTypeName or "", SBR.FormatDuration(m.duration), SBR.FormatTimestamp(m.startedAt)))

    local b = m.balance
    local r, g, bl = SBR.Report.BalanceColor(b)
    self.balanceValue:SetText(b and tostring(b) or "-")
    self.balanceValue:SetColor(r, g, bl, 1)
    self.balanceText:SetText(SBR.Report.BalanceText(b))
    self.balanceText:SetColor(r, g, bl, 1)
    local fw = math.max(2, 466 * Num(b) / 100)
    self.balanceFill:SetWidth(fw)
    SBR.Gradient(self.balanceFill, { r * 0.6, g * 0.6, bl * 0.6, 1 }, { r, g, bl, 1 }, true)
    self.balanceShine:SetWidth(fw)
    local teams = SortedTeams(m)
    self.balanceLeft:SetTexture(TeamEmblem(teams[1] or 1))
    self.balanceRight:SetTexture(TeamEmblem(teams[2] or teams[1] or 2))
    self.balanceRight:SetHidden(#teams < 2)

    for key, tab in pairs(self.tabs) do
        local on = key == self.tab
        Paint(tab.label, on and WHITE or NORMAL, on and 1 or 0.65)
        tab.icon:SetColor(1, 1, 1, on and 1 or 0.5)
        tab.underline:SetHidden(not on)
        tab.glow:SetHidden(not on)
        Paint(tab.glow, GOLD, 0.35)
    end
    self.texts:Reset()
    self.boxes:Reset()
    self.arts:Reset()
    if self.tab == "timeline" then self:RenderTimeline(m, f)
    elseif self.tab == "you" then self:RenderYou(m, f)
    else self:RenderOverview(m, f) end
    if self.keybinds then KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybinds) end
end

local function PlayerKey(p) return (p.displayName and p.displayName ~= "") and p.displayName or p.characterName end

function RP:RenderOverview(m, f)
    local body = self.body
    local totals = {}
    for _, p in pairs(m.players or {}) do
        local t = totals[p.team] or { kills = 0, damage = 0, healing = 0, players = 0 }
        local s = p.scores or {}
        t.kills, t.damage, t.healing = t.kills + Num(s.KILL), t.damage + Num(s.DAMAGE_DONE), t.healing + Num(s.HEALING_DONE)
        t.players = t.players + 1
        totals[p.team] = t
    end
    -- team cards on the team's own scoreboard background art
    local y = 0
    local teams = SortedTeams(m)
    local cardH = #teams > 2 and 112 or 146
    for i, id in ipairs(teams) do
        local t, rgb, tot = m.teams[id], TeamRGB(m, id), totals[id] or {}
        local card = Grad(self, { rgb[1], rgb[2], rgb[3], 0.42 }, { rgb[1], rgb[2], rgb[3], 0.06 }, 720, cardH, true)
        card:SetAnchor(TOPLEFT, body, TOPLEFT, 0, y)
        local edge = Box(self, rgb, 1, 4, cardH)
        edge:SetAnchor(TOPLEFT, card, TOPLEFT, 0, 0)
        local rim = Box(self, rgb, 0.45, 720, 1)
        rim:SetAnchor(TOPLEFT, card, TOPLEFT, 0, 0)
        if i == 1 then
            local crown = Art(self, ICON.glow, 170, 170, GOLD, 0.22)
            crown:SetAnchor(CENTER, card, LEFT, 64, 0)
        end
        local emblem = Art(self, TeamEmblem(id), 88, 88)
        emblem:SetAnchor(LEFT, card, LEFT, 18, 0)
        local name = Upper(Text(self, f.title, rgb, TEXT_ALIGN_LEFT, (t.name or "?") .. (id == m.localTeam and "  (you)" or ""), 420, 38))
        name:SetAnchor(TOPLEFT, card, TOPLEFT, 124, cardH > 120 and 18 or 10)
        local score = Text(self, f.giant, WHITE, TEXT_ALIGN_RIGHT, tostring(t.score or "-"), 180, 66)
        score:SetAnchor(RIGHT, card, RIGHT, -24, 0)
        Stat(self, f, card, 124, cardH > 120 and 72 or 58, ICON.kills, tostring(Num(tot.kills)), cardH > 120 and "kills" or nil)
        Stat(self, f, card, 254, cardH > 120 and 72 or 58, ICON.damage, N(tot.damage), cardH > 120 and "damage" or nil)
        Stat(self, f, card, 404, cardH > 120 and 72 or 58, ICON.healing, N(tot.healing), cardH > 120 and "healing" or nil)
        y = y + cardH + 14
    end

    -- MVP: class emblem on a gold glow
    local mvp
    for _, p in pairs(m.players or {}) do
        if not mvp or Num(p.scores and p.scores.SCORE) > Num(mvp.scores and mvp.scores.SCORE) then mvp = p end
    end
    if mvp then
        local top = y + 10
        local cap = Caption(self, f, "Match MVP", 300)
        cap:SetAnchor(TOPLEFT, body, TOPLEFT, 0, top)
        local glow = Art(self, ICON.glow, 200, 200, GOLD, 0.6)
        glow:SetAnchor(CENTER, body, TOPLEFT, 52, top + 84)
        local cls = Art(self, ClassIcon(mvp) or ICON.score, 72, 72)
        cls:SetAnchor(CENTER, body, TOPLEFT, 52, top + 84)
        local nm = Text(self, f.huge, GOLD, TEXT_ALIGN_LEFT, mvp.characterName or "?", 560, 56)
        nm:SetAnchor(TOPLEFT, body, TOPLEFT, 120, top + 36)
        local s = mvp.scores or {}
        Stat(self, f, body, 120, top + 98, ICON.score, N(s.SCORE), "score", GOLD)
        Stat(self, f, body, 260, top + 98, ICON.kills, tostring(Num(s.KILL)), "kills")
        Stat(self, f, body, 380, top + 98, ICON.deaths, tostring(Num(s.DEATH)), "deaths")
        Stat(self, f, body, 500, top + 98, ICON.assists, tostring(Num(s.ASSISTS)), "assists")
    end

    -- every player's title: title icon, name, title, best score first
    local cap = Caption(self, f, "Titles earned", 600)
    cap:SetAnchor(TOPLEFT, body, TOPLEFT, 770, 0)
    local list = {}
    for _, p in pairs(m.players or {}) do list[#list + 1] = p end
    table.sort(list, function(a, b) return Num(a.scores and a.scores.SCORE) > Num(b.scores and b.scores.SCORE) end)
    local titles = m.titles or {}
    for i, p in ipairs(list) do
        if i > 16 then break end
        local col, row = (i - 1) >= 8 and 1 or 0, (i - 1) % 8
        local x, yy = 770 + col * 360, 32 + row * 66
        if p.isLocal then
            local trgb = TeamRGB(m, p.team)
            local hl = Grad(self, { trgb[1], trgb[2], trgb[3], 0.45 }, { trgb[1], trgb[2], trgb[3], 0 }, 352, 58, true)
            hl:SetAnchor(TOPLEFT, body, TOPLEFT, x - 6, yy - 2)
        end
        local stripe = Box(self, TeamRGB(m, p.team), 1, 4, 54)
        stripe:SetAnchor(TOPLEFT, body, TOPLEFT, x, yy)
        local title = titles[PlayerKey(p)]
        local icon = Art(self, TitleIcon(title, p.team) or ICON.score, 36, 36)
        icon:SetAnchor(LEFT, stripe, RIGHT, 10, 0)
        local nm = Text(self, f.big, p.isLocal and GOLD or WHITE, TEXT_ALIGN_LEFT, p.characterName or "?", 280, 28)
        nm:SetAnchor(TOPLEFT, icon, TOPRIGHT, 10, -6)
        local tt = Text(self, f.small, NORMAL, TEXT_ALIGN_LEFT, (title or "-") .. (p == mvp and "  ·  MVP" or ""), 280, 24)
        tt:SetAnchor(TOPLEFT, nm, BOTTOMLEFT, 0, -2)
        if p == mvp then Paint(tt, GOLD) end
    end
end

-- bar chart: series[teamId] = { {t, v}, ... }; grouped bars per bucket, one per
-- team, filled with each team's capture-bar art. mirrored: team 1 above the
-- middle line, the others below.
function RP:Chart(m, f, top, title, icon, series, teams, height, fmt, mirrored)
    local body = self.body
    local width = PANEL_W - PAD * 2 - 120
    local ic = Art(self, icon, 28, 28)
    ic:SetAnchor(TOPLEFT, body, TOPLEFT, 0, top - 2)
    local cap = Caption(self, f, title, 600)
    cap:SetAnchor(LEFT, ic, RIGHT, 8, 0)
    local area = Box(self, { 1, 1, 1 }, 0.035, width, height)
    area:SetAnchor(TOPLEFT, body, TOPLEFT, 120, top + 30)
    for gl = 1, 3 do -- light grid lines
        local line = Box(self, { 1, 1, 1 }, 0.06, width, 1)
        line:SetAnchor(TOPLEFT, area, TOPLEFT, 0, height * gl / 4)
    end
    local buckets, maxV = 0, 0
    for _, id in ipairs(teams) do
        local s = series[id] or {}
        buckets = math.max(buckets, #s)
        for _, pt in ipairs(s) do maxV = math.max(maxV, Num(pt[2])) end
    end
    if buckets == 0 or maxV == 0 then
        local none = Text(self, f.small, DIM, TEXT_ALIGN_CENTER, "Not recorded for this match", width, height)
        none:SetAnchor(TOPLEFT, area, TOPLEFT, 0, 0)
        return
    end
    local step = math.max(1, math.ceil(buckets / 48))
    local shown = math.ceil(buckets / step)
    local slot = width / shown
    local nTeams = #teams
    -- bars never wider than 56 px, centred in their slot
    local barW = math.min(56, math.max(2, math.floor((slot - 4) / (mirrored and 1 or nTeams))))
    local inset = math.max(2, (slot - barW * (mirrored and 1 or nTeams)) / 2)
    local half = height / 2
    for bi = 1, shown do
        local idx = math.min(buckets, bi * step)
        for ti, id in ipairs(teams) do
            local pt = (series[id] or {})[idx]
            local v = pt and Num(pt[2]) or 0
            if v > 0 then
                local x = (bi - 1) * slot + inset
                local rgb = TeamRGB(m, id)
                local hi = { math.min(1, rgb[1] * 1.15), math.min(1, rgb[2] * 1.15), math.min(1, rgb[3] * 1.15), 1 }
                local lo = { rgb[1] * 0.55, rgb[2] * 0.55, rgb[3] * 0.55, 1 }
                if mirrored then
                    local h = (half - 2) * v / maxV
                    if ti == 1 then
                        local bar = Grad(self, hi, lo, barW, h)
                        bar:SetAnchor(BOTTOMLEFT, area, TOPLEFT, x, half)
                    else
                        local bar = Grad(self, lo, hi, barW, h)
                        bar:SetAnchor(TOPLEFT, area, TOPLEFT, x, half)
                    end
                else
                    local h = (height - 4) * v / maxV
                    local bar = Grad(self, hi, lo, barW - 2, h)
                    bar:SetAnchor(BOTTOMLEFT, area, BOTTOMLEFT, x + (ti - 1) * barW, 0)
                end
            end
        end
    end
    if mirrored then
        local mid = Art(self, ICON.divider, width, 6, nil, 0.8)
        mid:SetAnchor(LEFT, area, TOPLEFT, 0, half)
    end
    local maxL = Text(self, f.tiny, DIM, TEXT_ALIGN_RIGHT, fmt(maxV), 110, 22)
    maxL:SetAnchor(TOPRIGHT, area, TOPLEFT, -10, 0)
    local firstT = ((series[teams[1]] or {})[1] or {})[1] or 0
    local lastT = ((series[teams[1]] or {})[buckets] or {})[1] or 0
    local t0 = Text(self, f.tiny, DIM, TEXT_ALIGN_LEFT, SBR.FormatDuration(firstT), 120, 22)
    t0:SetAnchor(TOPLEFT, area, BOTTOMLEFT, 0, 2)
    local t1 = Text(self, f.tiny, DIM, TEXT_ALIGN_RIGHT, SBR.FormatDuration(lastT), 120, 22)
    t1:SetAnchor(TOPRIGHT, area, BOTTOMRIGHT, 0, 2)
end

function RP:RenderTimeline(m, f)
    local R = SBR.Report
    local teams = SortedTeams(m)
    self:Chart(m, f, 0, "Score over time", ICON.score, R:Series(m, 1), teams, 132, function(v) return N(v) end)
    self:Chart(m, f, 200, "Damage race (team damage done)", ICON.damage, R:Series(m, 2), teams, 132, function(v) return N(v) end)
    local perMin, minutes = R:Momentum(m)
    local series = {}
    for _, id in ipairs(teams) do
        local list = {}
        for mi = 1, minutes do list[mi] = { (mi - 1) * 60, (perMin[id] or {})[mi] or 0 } end
        series[id] = list
    end
    self:Chart(m, f, 400, "Momentum (kills per minute)", ICON.kills, series, teams, 150, function(v) return tostring(v) end, true)
    -- legend: team emblems
    local x = 0
    for _, id in ipairs(teams) do
        local em = Art(self, TeamEmblem(id), 34, 34)
        em:SetAnchor(TOPRIGHT, self.body, TOPRIGHT, -(#teams - 1) * 240 + x - 200, -4)
        local nm = Upper(Text(self, f.small, TeamRGB(m, id), TEXT_ALIGN_LEFT, m.teams[id].name or "?", 190, 26))
        nm:SetAnchor(LEFT, em, RIGHT, 8, 0)
        x = x + 240
    end
end

function RP:RenderYou(m, f)
    local body = self.body
    local h = m.haul or {}
    local rankName = h.rank and SBR.CleanName(SBR.API("GetAvARankName", GENDER_MALE or 1, h.rank) or "") or nil
    local tiles = {
        { APIcon(), h.ap and ("+" .. N(h.ap)) or "-", "Alliance points", { 0.55, 0.78, 1 } },
        { ICON.xp, h.xp and ("+" .. N(h.xp)) or "-", "Experience", { 0.70, 0.90, 0.55 } },
        { ICON.cp, h.cp and ((h.cp >= 0 and "+" or "") .. h.cp) or "-", "Champion points", { 1, 0.82, 0.45 } },
        { ICON.medals, tostring(h.medals or #(m.myMedals or {})), "Medals", GOLD },
        { (h.rank and SBR.API("GetAvARankIcon", h.rank)) or ICON.score, rankName or "-", h.rankUp and "Rank up!" or "Alliance rank", h.rankUp and GOLD or WHITE },
    }
    for i, t in ipairs(tiles) do
        local x = (i - 1) * 296
        local box = Box(self, { 1, 1, 1 }, 0.05, 284, 108)
        box:SetAnchor(TOPLEFT, body, TOPLEFT, x, 0)
        local edge = Box(self, t[4], 0.9, 284, 3)
        edge:SetAnchor(TOPLEFT, box, TOPLEFT, 0, 0)
        local glow = Art(self, ICON.glow, 140, 140, t[4], 0.25)
        glow:SetAnchor(CENTER, box, LEFT, 52, 0)
        local ic = Art(self, t[1], 56, 56)
        ic:SetAnchor(LEFT, box, LEFT, 24, 0)
        local v = Text(self, f.title, t[4], TEXT_ALIGN_LEFT, t[2], 190, 40)
        v:SetAnchor(TOPLEFT, box, TOPLEFT, 96, 20)
        local cap = Upper(Text(self, f.tiny, DIM, TEXT_ALIGN_LEFT, t[3], 180, 22))
        cap:SetAnchor(TOPLEFT, v, BOTTOMLEFT, 0, 2)
    end

    -- your title: big icon on a glow
    local me
    for _, p in pairs(m.players or {}) do if p.isLocal then me = p break end end
    local title = me and m.titles and m.titles[PlayerKey(me)]
    local cap = Caption(self, f, "Your title this match", 400)
    cap:SetAnchor(TOPLEFT, body, TOPLEFT, 0, 138)
    local glow = Art(self, ICON.glow, 230, 230, GOLD, 0.55)
    glow:SetAnchor(CENTER, body, TOPLEFT, 60, 230)
    local ti = Art(self, TitleIcon(title, me and me.team or 1) or ICON.score, 64, 64)
    ti:SetAnchor(CENTER, body, TOPLEFT, 60, 230)
    local tt = Text(self, f.giant, GOLD, TEXT_ALIGN_LEFT, title or "-", 560, 66)
    tt:SetAnchor(TOPLEFT, body, TOPLEFT, 130, 186)
    local hint = Text(self, f.small, NORMAL, TEXT_ALIGN_LEFT, "The stat where you came closest to the best player in the match.", 600, 28)
    hint:SetAnchor(TOPLEFT, tt, BOTTOMLEFT, 0, 0)

    -- medals: icons with a count badge
    local mcap = Caption(self, f, "Your medals", 400)
    mcap:SetAnchor(TOPLEFT, body, TOPLEFT, 0, 318)
    local counts, order = {}, {}
    for _, md in ipairs(m.myMedals or {}) do
        local k = md.name or md.id
        if not counts[k] then counts[k] = { name = md.name, icon = md.icon, n = 0 }; order[#order + 1] = counts[k] end
        counts[k].n = counts[k].n + 1
    end
    for i, md in ipairs(order) do
        if i > 8 then break end
        local x = ((i - 1) % 4) * 172
        local yy = 352 + math.floor((i - 1) / 4) * 128
        local ic = Art(self, (type(md.icon) == "string" and md.icon ~= "") and md.icon or ICON.medals, 64, 64)
        ic:SetAnchor(TOP, body, TOPLEFT, x + 80, yy)
        local nm = Text(self, f.tiny, NORMAL, TEXT_ALIGN_CENTER, (md.name or "?") .. (md.n > 1 and ("  |cF2D17Ax" .. md.n .. "|r") or ""), 164, 22)
        nm:SetAnchor(TOP, ic, BOTTOM, 0, 4)
    end
    if #order == 0 then
        local none = Text(self, f.small, DIM, TEXT_ALIGN_LEFT, "No medals this time.", 400, 30)
        none:SetAnchor(TOPLEFT, body, TOPLEFT, 0, 352)
    end

    -- profile: stat icon, name, framed bar in your team's colours, percentage
    local pcap = Caption(self, f, "Your profile (against the best in the match)", 700)
    pcap:SetAnchor(TOPLEFT, body, TOPLEFT, 760, 138)
    local team = me and me.team or 1
    local AXIS_ICON = { kills = ICON.kills, damage = ICON.damage, healing = ICON.healing, assists = ICON.assists,
        objectives = TITLE_ICON["Objective runner"], medals = TITLE_ICON.Medalist, survival = ICON.shield }
    -- columns inside the 1480 px body: icon 32 | label 200 | bar 380 | value 80 (ends at 1470)
    local teamRgb = TeamRGB(m, team)
    for i, axis in ipairs(m.profile or {}) do
        local yy = 178 + (i - 1) * 56
        local ic = Art(self, AXIS_ICON[axis.key] or ICON.score, 32, 32)
        ic:SetAnchor(TOPLEFT, body, TOPLEFT, 760, yy)
        local l = Text(self, f.big, WHITE, TEXT_ALIGN_LEFT, axis.label, 200, 32)
        l:SetAnchor(LEFT, ic, RIGHT, 10, 0)
        local share = math.max(0, math.min(1, Num(axis.share)))
        local best = share >= 0.999
        Bar(self, l, LEFT, RIGHT, 4, 0, 380, share, best and GOLD or teamRgb)
        local v = Text(self, best and f.big or f.text, best and GOLD or WHITE, TEXT_ALIGN_RIGHT,
            best and "Best" or string.format("%d%%", math.floor(share * 100 + 0.5)), 80, 32)
        v:SetAnchor(LEFT, l, RIGHT, 388, 0)
    end
end

---------------------------------------------------------------------------
-- scenes, keybinds, opening
---------------------------------------------------------------------------
function RP:SetTab(tab)
    if tab == self.tab then return end
    self.tab = tab
    if SOUNDS and SOUNDS.GAMEPAD_MENU_FORWARD then PlaySound(SOUNDS.GAMEPAD_MENU_FORWARD) end
    self:Render()
end

function RP:CycleTab(delta)
    local i = 1
    for k, key in ipairs(TABS) do if key == self.tab then i = k end end
    self:SetTab(TABS[((i - 1 + delta) % #TABS) + 1])
end

function RP:StoredIndex()
    if not self.match then return nil end
    local _, index = SBR.MatchDB:FindMatch(self.match.id)
    return index
end

function RP:BuildKeybinds()
    self.keybinds = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        { name = "Scoreboard", keybind = "UI_SHORTCUT_PRIMARY", visible = function() return RP:StoredIndex() ~= nil end,
          callback = function()
              SBR.Window.viewIndex = RP:StoredIndex()
              SBR.Window:Show(true)
          end },
        { name = "Back", keybind = "UI_SHORTCUT_NEGATIVE", callback = function() RP:Close() end },
        { name = "Previous tab", keybind = "UI_SHORTCUT_LEFT_SHOULDER", callback = function() RP:CycleTab(-1) end },
        { name = "Next tab", keybind = "UI_SHORTCUT_RIGHT_SHOULDER", callback = function() RP:CycleTab(1) end },
    }
end

function RP:Init()
    if self.keyboardScene or not (ZO_Scene and SCENE_MANAGER and KEYBIND_STRIP) then return end
    self:Create()
    local fragment = ZO_SimpleSceneFragment:New(self.control)
    local function scene(name, group)
        local sc = ZO_Scene:New(name, SCENE_MANAGER)
        sc:AddFragment(fragment)
        if group then sc:AddFragmentGroup(group) end
        if MINIMIZE_CHAT_FRAGMENT then sc:AddFragment(MINIMIZE_CHAT_FRAGMENT) end
        sc:RegisterCallback("StateChange", function(_, newState)
            if newState == SCENE_SHOWN then RP:OnShown()
            elseif newState == SCENE_HIDING then KEYBIND_STRIP:RemoveKeybindButtonGroup(RP.keybinds) end
        end)
        return sc
    end
    self.keyboardScene = scene(self.keyboardSceneName, FRAGMENT_GROUP and FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
    self.gamepadScene = scene(self.gamepadSceneName, FRAGMENT_GROUP and FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    self:BuildKeybinds()
end

function RP:FitToScreen()
    local w = GuiRoot and GuiRoot:GetWidth() or DESIGN_W
    local h = GuiRoot and GuiRoot:GetHeight() or DESIGN_H
    self.frame:SetScale(math.min(1, w / DESIGN_W, h / DESIGN_H))
end

function RP:OnShown()
    self:FitToScreen()
    self:Render()
    KEYBIND_STRIP:AddKeybindButtonGroup(self.keybinds)
end

function RP:IsShowing()
    return (self.keyboardScene and self.keyboardScene:IsShowing()) or (self.gamepadScene and self.gamepadScene:IsShowing()) or false
end

-- match: a match table (history entry), or nil for the latest finished match
function RP:Open(match, tab)
    match = match or SBR.MatchLog:GetHistory()[#SBR.MatchLog:GetHistory()]
    if not match then
        SBR.Print("No finished match to report yet.")
        return
    end
    self:Init()
    if not self.keyboardScene then return end
    self.match = SBR.Realize(match)
    self.tab = tab or "overview"
    if self:IsShowing() then self:Render() return end
    SCENE_MANAGER:Push(SBR.IsGamepad() and self.gamepadSceneName or self.keyboardSceneName)
end

function RP:Close()
    if self:IsShowing() then SCENE_MANAGER:HideCurrentScene() end
end

-- After a finished match: open its report once you're out of the battleground.
function RP:OnPlayerActivated()
    local pending = SBR.MatchLog.reportPending
    if not pending or SBR.Battleground:IsInBattleground() then return end
    SBR.MatchLog.reportPending = nil
    if SBR.sv.autoReport == false then return end
    zo_callLater(function() RP:Open(pending) end, 2000)
end

ScoreboardRemastered.Mark("UI/Report.lua")
