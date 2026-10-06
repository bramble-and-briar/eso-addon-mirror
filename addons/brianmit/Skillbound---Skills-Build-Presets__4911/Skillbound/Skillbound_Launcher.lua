-- Skillbound_Launcher.lua : the button, design 1 "slim bar, refined" (picked 2026-10-01)
-- in look K: warm near-black bar, gold-dark frame with a lit top edge, the logo (sword
-- through a ring), then the favorite builds as square slots with a soft quality glow.
--   Click the logo = open / close the window; click a favorite = wear it right away.
-- Motion (same language as the window, Skillbound_Anim.lua):
--   hover a slot: it lifts 2 px, its frame lights up, the name shows (120 ms);
--   the amber "worn" line glides to the build you put on (220 ms);
--   while a build goes on: a warm light breathes behind the logo, a line fills along
--   the bottom step by step; when it's done the logo pulses once;
--   orange / red dot on the logo = the build check found something (hover: what).
-- The button is a movable window, which swallows its children's clicks, so the part
-- under the mouse is found by position (same as Questbound / Set Hunter).

local B = Skillbound
local L = B.L
local C = B.COLOR
local W = B.W
local Anim = B.Anim
local Launcher = {}
B.Launcher = Launcher

local H = 42          -- bar height
local LOGO = 30
local LOGO_W = 36     -- logo area width
local FAV = 28
local GAP = 6
local PAD = 6

local ui = { favs = {} }
local inCombat = false
local hoverPart

local FOLD_TO = 5     -- folded: only the first 5 favorites
local ARROW_W = 16    -- the fold arrow at the right end (only with more than 5 slots)

local function Slots() return zo_clamp(B.sv.launcher.slots or B.MAX_FAV, 0, B.MAX_FAV) end
local function Foldable(n) return n > FOLD_TO end
local function Shown(n)
    if Foldable(n) and B.sv.launcher.folded then return FOLD_TO end
    return n
end
local function BarWidth(n, shown)
    local width = PAD + LOGO_W + GAP + 1
    if shown > 0 then width = width + GAP + shown * FAV + (shown - 1) * GAP end
    if Foldable(n) then width = width + GAP + ARROW_W - 4 end
    return width + PAD
end

local function Place()
    local s = B.sv.launcher
    if s.x and s.y then
        Anim.Anchor(ui.win, TOPLEFT, GuiRoot, TOPLEFT, s.x, s.y)
    else
        Anim.Anchor(ui.win, TOPLEFT, GuiRoot, TOPLEFT, 16, 168)   -- under the Command Codex / Set Hunter buttons
    end
end

local function FavX(i) return PAD + LOGO_W + GAP + 1 + GAP + (i - 1) * (FAV + GAP) end

local function MakeFav(i)
    local f = WINDOW_MANAGER:CreateControl(nil, ui.win, CT_CONTROL)
    f:SetDimensions(FAV, FAV)
    f.bg = W.Tex(f)
    f.bg:SetAnchorFill(f)
    f.bg:SetColor(B.RGBA(C.slot, 1))
    f.icon = W.Tex(f, nil, FAV - 4, FAV - 4)
    f.icon:SetAnchor(CENTER, f, CENTER, 0, 0)
    f.quality = W.Tex(f, B.TEX .. "fade_up.dds", FAV - 2, 9)
    f.quality:SetAnchor(BOTTOM, f, BOTTOM, 0, -1)
    f.frame = W.Frame(f, C.edge, 1)
    f.plus = W.Label(f, B.Font("bold", 16), C.faint, "+", TEXT_ALIGN_CENTER)
    f.plus:SetAnchor(CENTER, f, CENTER, 0, -1)
    f.light = W.Glow(f, FAV * 1.9, FAV * 1.9, C.glow, 0)
    f.light:SetAnchor(CENTER, f, CENTER, 0, 0)
    f.index = i
    f.lift = 0
    f.key = "Skillbound_Fav" .. i
    Anim.Anchor(f, LEFT, ui.win, LEFT, FavX(i), 0)
    ui.favs[i] = f
    return f
end

-- the logo tile: hover eases the frame to amber, lifts it 2 px and lights it up (halo behind,
-- the logo brighter) in 220 ms; before the first click the halo breathes softly instead
-- (see the OnUpdate in Init)
local function PaintLogo()
    local p = ui.logoHoverP
    local e, t = C.edge, C.theme
    ui.logoFrame:SetFrameColor({ r = Anim.Lerp(e.r, t.r, p), g = Anim.Lerp(e.g, t.g, p), b = Anim.Lerp(e.b, t.b, p) }, 1)
    Anim.Offset(ui.logoBox, 0, -2 * p)
    ui.logoHalo:SetScale(0.7 + 0.3 * p)
    if B.sv.launcher.clicked or not Anim.Enabled() then ui.logoHalo:SetAlpha(0.4 * p) end
    ui.logoInner:SetAlpha(0.35 * p)
    ui.logoBright:SetAlpha(0.45 * p)
end

local function LogoHover(on)
    local from = ui.logoHoverP
    Anim.Run("Skillbound_LogoHover", Anim.STD, Anim.Out, function(p)
        ui.logoHoverP = Anim.Lerp(from, on and 1 or 0, p)
        PaintLogo()
    end)
end

-- click: the tile dips, a ring ripples out; the breathing hint stops for good
local function LogoClicked()
    B.sv.launcher.clicked = true
    Anim.Pulse(ui.logoBox, 0.88, 180, "Skillbound_LogoDip")
    ui.logoRipple:SetHidden(false)
    Anim.Run("Skillbound_LogoRipple", 450, Anim.Out, function(p)
        ui.logoRipple:SetScale(1 + 0.9 * p)
        ui.logoRipple:SetAlpha(0.9 * (1 - p))
    end, function() ui.logoRipple:SetHidden(true) end, 0, true)
    PaintLogo()
end

-- what's under the mouse: "logo", a favorite index, or "bar"
local function PartUnderMouse()
    if B.IsOver(ui.logoArea, 0) then return "logo" end
    if not ui.arrowArea:IsHidden() and B.IsOver(ui.arrowArea, 2) then return "arrow" end
    for i = 1, Shown(Slots()) do
        local f = ui.favs[i]
        if f and not f:IsHidden() and B.IsOver(f, 3) then return i end
    end
    return "bar"
end

-- a slot lifts 2 px and lights up while hovered
local function Lift(f, on)
    local from = f.lift
    Anim.Run(f.key, Anim.MICRO, Anim.Out, function(p)
        f.lift = Anim.Lerp(from, on and 1 or 0, p)
        Anim.Offset(f, 0, -2 * f.lift)
        f.light:SetAlpha(0.3 * f.lift)
    end)
end

-- the amber "worn" line glides under the worn favorite
local function MoveWorn(index, instant)
    if not index then
        ui.worn:SetHidden(true)
        ui.wornGlow:SetHidden(true)
        ui.wornIndex = nil
        return
    end
    ui.worn:SetHidden(false)
    ui.wornGlow:SetHidden(false)
    local to = FavX(index)
    local from = ui.wornX or to
    ui.wornIndex, ui.wornX = index, to
    local function Set(x)
        ui.worn:ClearAnchors()
        ui.worn:SetAnchor(TOPLEFT, ui.win, TOPLEFT, x, H / 2 + FAV / 2 + 3)
    end
    if instant or from == to then
        Set(to)
        return
    end
    Anim.Run("Skillbound_WornLine", Anim.STD, Anim.InOut, function(p) Set(Anim.Lerp(from, to, p)) end)
end

function Launcher.Update()
    if not ui.win then return end
    local s = B.sv.launcher
    local n = Slots()
    local shown = Shown(n)
    local c = B.Char()
    local fav = c.fav
    local wornIndex
    for i = 1, B.MAX_FAV do
        local f = ui.favs[i] or (i <= n and MakeFav(i))
        if f then
            -- (while folding / unfolding the animation decides what's visible)
            if not ui.folding then
                f:SetHidden(i > shown)
                f:SetAlpha(1)
            end
            if i <= n then
                local b = B.Get(fav[i])
                f.icon:SetHidden(b == nil)
                f.plus:SetHidden(b ~= nil)
                f.quality:SetHidden(b == nil)
                local worn = b and (c.worn == b.id or c.layer == b.id)
                if worn and i <= shown then wornIndex = i end
                if b then
                    f.icon:SetTexture(B.UI.BuildIcon(b))
                    local p = b.gear and (b.gear[EQUIP_SLOT_MAIN_HAND] or b.gear[EQUIP_SLOT_CHEST])
                    local q = GetItemQualityColor(p and p.q or ITEM_DISPLAY_QUALITY_LEGENDARY)
                    f.quality:SetColor(q.r, q.g, q.b, 0.4)
                end
                f.icon:SetAlpha(worn and 1 or 0.85)
                f.frame:SetFrameColor(hoverPart == i and C.text or (worn and C.theme or (b and C.edge or C.line)), 1)
            end
        end
    end
    if wornIndex ~= ui.wornIndex then MoveWorn(wornIndex, ui.wornIndex == nil) end
    if not ui.folding then
        ui.win:SetWidth(BarWidth(n, shown))
        ui.arrow:SetTextureRotation(s.folded and 0 or math.pi, 0.5, 0.5)   -- ">" folded, "<" open
    end
    ui.arrowArea:SetHidden(not Foldable(n))
    ui.arrow:SetColor(B.RGBA(hoverPart == "arrow" and C.text or C.gold, 1))
    ui.arrow:SetScale(hoverPart == "arrow" and 1.2 or 1)
    ui.sep:SetHidden(n == 0)

    -- rules pip under the logo: amber = rules on, hollow grey = paused, none = no rules
    local hasRules = #B.sv.rules > 0
    ui.rulesPip:SetHidden(not hasRules)
    if hasRules then
        local paused = B.Rules.IsPaused()
        ui.rulesPip:SetTexture(B.TEX .. (paused and "ring.dds" or "disc.dds"))
        ui.rulesPip:SetColor(B.RGBA(paused and C.dim or C.theme))
    end

    local level = B.Check.Level()
    ui.dot:SetHidden(level == nil)
    if level then ui.dot:SetColor(B.RGBA(level == "bad" and C.bad or C.warn)) end

    -- putting a build on: light breathes behind the logo, the bottom line fills step by step
    local build, done, total, waiting = B.Apply.Progress()
    ui.busy = build ~= nil
    ui.bar:SetHidden(build == nil)
    ui.barFill:SetHidden(build == nil)
    if build then
        local to = (ui.win:GetWidth() - 2) * (total > 0 and done / total or 0)
        local from = ui.barW or 0
        ui.barW = to
        ui.barFill:SetColor(B.RGBA(waiting and C.warn or C.theme))
        Anim.Run("Skillbound_LauncherBar", Anim.MICRO, Anim.Out, function(p)
            ui.barFill:SetWidth(math.max(2, Anim.Lerp(from, to, p)))
        end)
    else
        ui.barW = 0
        ui.logoLight:SetAlpha(0)   -- (only while a build goes on; hover has the amber glow now)
    end
    B.ShowOnHud(ui.fragment, not s.hidden and not (s.combatHide and inCombat and not build))
end

-- fold to 5 slots / unfold to all: the bar slides shorter / longer (220 ms), the extra
-- slots fade out quickly before the edge passes them (or fade in after it opened up,
-- one after another), and the arrow turns half round
function Launcher.Fold(fold)
    local n = Slots()
    if not Foldable(n) then return end
    B.sv.launcher.folded = fold or nil
    local fromW, toW = ui.win:GetWidth(), BarWidth(n, Shown(n))
    ui.folding = true
    for i = FOLD_TO + 1, n do
        if ui.favs[i] then ui.favs[i]:SetHidden(false) end
    end
    Launcher.Update()   -- (the worn line leaves a slot that folds away)
    Anim.Run("Skillbound_LauncherFold", Anim.STD, Anim.InOut, function(p)
        ui.win:SetWidth(Anim.Lerp(fromW, toW, p))
        ui.arrow:SetTextureRotation(fold and math.pi * (1 - p) or math.pi * p, 0.5, 0.5)
        for i = FOLD_TO + 1, n do
            local f = ui.favs[i]
            if f then
                local k = i - FOLD_TO - 1   -- 0 = next to the 5th slot
                local a
                if fold then
                    a = 1 - zo_clamp(p * 2.2 - (n - i) * 0.15, 0, 1)   -- the last slot goes first
                else
                    a = zo_clamp(p * 2.2 - 0.6 - k * 0.15, 0, 1)      -- the 6th slot comes first
                end
                f:SetAlpha(a)
            end
        end
    end, function()
        ui.folding = false
        Launcher.Update()
    end)
end

local function Tooltip(part)
    ClearTooltip(InformationTooltip)
    if part == "arrow" then
        InitializeTooltip(InformationTooltip, ui.arrowArea, TOP, 0, 10, BOTTOM)
        SetTooltipText(InformationTooltip, L(B.sv.launcher.folded and "LAUNCHER_UNFOLD_TT" or "LAUNCHER_FOLD_TT", FOLD_TO))
    elseif part == "logo" then
        InitializeTooltip(InformationTooltip, ui.win, TOPLEFT, 0, 6, BOTTOMLEFT)
        local lines = {}
        local worn = B.WornBuild()
        lines[#lines + 1] = worn and B.Colorize(C.theme, L("LAUNCHER_WEARING", worn.name)) or B.Colorize(C.dim, L("CHECK_NONE"))
        local build, done, total, waiting = B.Apply.Progress()
        if build then
            lines[#lines + 1] = B.Colorize(C.warn, waiting and L("LAUNCHER_WAITING", build.name) or L("LAUNCHER_PUTTING_ON", build.name, done, total))
        end
        -- (one short line, not the whole check list: that sits in the window's build line and
        -- on the Gear check tab; the long list made this tooltip an untidy wall of text)
        if worn then
            local bad, n = false, 0
            for _, line in ipairs(B.Check.Current()) do
                n = n + 1
                if line.level == "bad" then bad = true end
            end
            if n > 0 then
                lines[#lines + 1] = B.Dot(bad and C.bad or C.warn) .. " " .. L("CHECK_SHORT_N", n)
            else
                lines[#lines + 1] = B.Dot(C.good) .. " " .. L("CHECK_SHORT_GOOD")
            end
        end
        if #B.sv.rules > 0 then
            lines[#lines + 1] = B.Rules.IsPaused() and B.Colorize(C.dim, L("LAUNCHER_RULES_OFF"))
                or B.Colorize(C.theme, L("LAUNCHER_RULES_ON"))
        end
        lines[#lines + 1] = B.Colorize(C.dim, L("LAUNCHER_TT"))
        SetTooltipText(InformationTooltip, table.concat(lines, "\n"))
    elseif type(part) == "number" then
        local f = ui.favs[part]
        InitializeTooltip(InformationTooltip, f, TOP, 0, 10, BOTTOM)
        local b = B.Get(B.Char().fav[part])
        if b and b.note and b.note ~= "" then
            SetTooltipText(InformationTooltip, B.UI.NoteTooltip(b, L("FAV_SLOT_TT")))   -- (with the build's notes)
        elseif b then
            SetTooltipText(InformationTooltip, b.name .. "\n" .. B.Colorize(C.dim, L("FAV_SLOT_TT")))
        else
            SetTooltipText(InformationTooltip, L("FAV_EMPTY_TT"))
        end
    end
end

local function PickForSlot(i)
    ClearMenu()
    local list = B.SortedBuilds()
    if #list == 0 then
        AddMenuItem(L("LIST_EMPTY_SHORT"), function() B.UI.Show() end)
    end
    for _, b in ipairs(list) do
        AddMenuItem(b.name, function()
            local fav = B.Char().fav
            -- the same build twice makes no sense: move it
            for j = #fav, 1, -1 do
                if fav[j] == b.id then table.remove(fav, j) end
            end
            if i > #fav + 1 then i = #fav + 1 end
            if fav[i] then fav[i] = b.id else fav[#fav + 1] = b.id end
            B.callbacks:FireCallbacks("BuildsChanged")
        end)
    end
    ShowMenu(ui.win)
end

local function FavMenu(i)
    local b = B.Get(B.Char().fav[i])
    -- a menu opened from inside a menu click is closed again by the game right after the
    -- click: open the build list a moment later
    local function PickLater() B.Later(function() PickForSlot(i) end, 50) end
    ClearMenu()
    if b then
        AddMenuItem(L("MENU_WEAR"), function() B.UI.AskWear(b) end)
        AddMenuItem(L("MENU_SHOW"), function() B.UI.Show() B.UI.Select(b.id) end)
        AddMenuItem(L("FAV_CHANGE"), PickLater)
        AddMenuItem(L("FAV_REMOVE"), function() B.ToggleFavorite(b.id) end)
    else
        AddMenuItem(L("FAV_PICK"), PickLater)
    end
    ShowMenu(ui.win)
end

local function MainMenu()
    ClearMenu()
    AddMenuItem(L("LAUNCHER_OPEN"), B.UI.Toggle)
    AddMenuItem(L("SAVE_WORN"), function() B.UI.SaveNew() end)
    if B.Char().undo then AddMenuItem(L("UNDO_MENU", B.Char().undo.name), B.Apply.Undo) end
    AddMenuItem(L("CHECK_MENU"), B.Check.PrintCurrent)
    if #B.sv.rules > 0 then
        AddMenuItem(L(B.Rules.IsPaused() and "LAUNCHER_RULES_RESUME" or "LAUNCHER_RULES_PAUSE"), B.Rules.TogglePaused)
    end
    AddMenuItem(L("LAUNCHER_HIDE"), function()
        B.sv.launcher.hidden = true
        Launcher.Update()
        B.Print(L("HIDDEN_HINT"))
    end)
    AddMenuItem(L("SETTINGS"), B.OpenSettings)
    ShowMenu(ui.win)
end

function Launcher.Init()
    local win = WINDOW_MANAGER:CreateTopLevelWindow("Skillbound_Launcher")
    ui.win = win
    win:SetHeight(H)
    win:SetClampedToScreen(true)
    win:SetMouseEnabled(true)
    win:SetMovable(true)
    Place()

    ui.bg = W.Tex(win, B.BG)
    ui.bg:SetAnchorFill(win)
    ui.bg:SetTextureCoords(0.2, 0.8, 0.72, 0.92)   -- a slice of the ember background (the warm glow)
    ui.frame = W.Frame(win, C.goldDark, 1)
    W.TopLight(win, 6, 0.45)

    -- logo, with a warm light behind it (hover / while a build goes on)
    ui.logoArea = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    ui.logoArea:SetDimensions(LOGO_W, H)
    ui.logoArea:SetAnchor(LEFT, win, LEFT, PAD, 0)
    ui.logoLight = W.Glow(win, LOGO * 2.2, LOGO * 2.2, C.glow, 0)
    ui.logoLight:SetAnchor(CENTER, ui.logoArea, CENTER, 0, 0)
    -- the logo as a button (sketches 1 + 2 + 5, picked 2026-10-01):
    --   1 a framed dark tile like the favorite slots; hover: frame turns amber, it lifts 2 px
    --   2 a breathing amber ring around it until you've clicked it once (then only on hover)
    --   5 click: the tile dips, an amber ring ripples out
    ui.logoBox = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    ui.logoBox:SetDimensions(LOGO + 4, LOGO + 4)
    Anim.Anchor(ui.logoBox, CENTER, ui.logoArea, CENTER, 0, 0)
    local tile = W.Tex(ui.logoBox)
    tile:SetAnchorFill(ui.logoBox)
    tile:SetColor(B.RGBA(C.slot, 1))
    ui.logoFrame = W.Frame(ui.logoBox, C.edge, 1)
    ui.logo = W.Tex(ui.logoBox, B.LOGO, LOGO - 4, LOGO - 4)
    ui.logo:SetAnchor(CENTER, ui.logoBox, CENTER, 0, 0)
    ui.logo:SetDrawLevel(3)
    -- hover glow (sketch A + C, replaced the ring): a soft amber halo swells up behind the
    -- tile, and the logo itself lights up (an additive copy of it + a small glow right around it)
    ui.logoHalo = W.Glow(win, LOGO * 2.6, LOGO * 2.6, C.theme, 0)
    ui.logoHalo:SetAnchor(CENTER, ui.logoBox, CENTER, 0, 0)
    ui.logoHalo:SetDrawLevel(0)
    ui.logoInner = W.Glow(ui.logoBox, LOGO, LOGO, C.theme, 0)
    ui.logoInner:SetAnchor(CENTER, ui.logoBox, CENTER, 0, 0)
    ui.logoInner:SetDrawLevel(2)
    ui.logoBright = W.Tex(ui.logoBox, B.LOGO, LOGO - 4, LOGO - 4)
    if ui.logoBright.SetBlendMode then ui.logoBright:SetBlendMode(TEX_BLEND_MODE_ADD) end
    ui.logoBright:SetAnchor(CENTER, ui.logo, CENTER, 0, 0)
    ui.logoBright:SetDrawLevel(4)
    ui.logoBright:SetAlpha(0)
    ui.logoRipple = W.Tex(win, B.TEX .. "ring.dds", LOGO + 4, LOGO + 4, C.theme, 0)
    ui.logoRipple:SetAnchor(CENTER, ui.logoBox, CENTER, 0, 0)
    ui.logoRipple:SetDrawLevel(5)
    ui.logoRipple:SetHidden(true)
    ui.logoHoverP = 0
    ui.dot = W.Tex(win, B.TEX .. "disc.dds", 9, 9, C.warn)
    ui.dot:SetAnchor(CENTER, ui.logoArea, CENTER, 11, -12)
    ui.dot:SetDrawLevel(6)
    ui.rulesPip = W.Tex(win, B.TEX .. "disc.dds", 7, 7, C.theme)
    ui.rulesPip:SetAnchor(CENTER, ui.logoArea, CENTER, -12, 13)
    ui.rulesPip:SetDrawLevel(6)
    ui.sep = W.Tex(win, nil, 1, H - 14, C.line)
    ui.sep:SetAnchor(LEFT, ui.logoArea, RIGHT, GAP, 0)

    -- fold arrow at the right end (chevron.dds points right; turned half round = "<")
    ui.arrowArea = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    ui.arrowArea:SetDimensions(ARROW_W, H)
    ui.arrowArea:SetAnchor(RIGHT, win, RIGHT, -PAD + 2, 0)
    ui.arrow = W.Tex(ui.arrowArea, B.TEX .. "chevron.dds", 14, 14, C.gold)
    ui.arrow:SetAnchor(CENTER, ui.arrowArea, CENTER, 0, 0)
    ui.arrow:SetDrawLevel(3)

    -- the worn line (amber, with a soft glow)
    ui.wornGlow = W.Glow(win, FAV + 20, 12, C.theme, 0.45)
    ui.worn = W.Tex(win, nil, FAV, 2, C.theme)
    ui.wornGlow:SetAnchor(CENTER, ui.worn, CENTER, 0, 0)
    ui.worn:SetDrawLevel(5)
    ui.worn:SetHidden(true)
    ui.wornGlow:SetHidden(true)

    -- progress line along the bottom edge
    ui.bar = W.Tex(win)
    ui.bar:SetColor(B.RGBA(C.line))
    ui.bar:SetHeight(2)
    ui.bar:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, 1, -1)
    ui.bar:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -1, -1)
    ui.barFill = W.Tex(win, nil, 2, 2, C.theme)
    ui.barFill:SetAnchor(LEFT, ui.bar, LEFT, 0, 0)
    ui.barFill:SetDrawLevel(4)

    -- hover: tooltip, lifted slot, light behind the logo
    local function Hover()
        -- a window opened over the button: the game sends no mouse-exit, so end the hover here
        local over = WINDOW_MANAGER:GetMouseOverControl()
        if over ~= ui.win then
            local handler = ui.win:GetHandler("OnMouseExit")
            if handler then handler(ui.win) end
            return
        end
        local part = PartUnderMouse()
        if part ~= hoverPart then
            local old = hoverPart
            hoverPart = part
            if type(old) == "number" and ui.favs[old] then Lift(ui.favs[old], false) end
            if type(part) == "number" and ui.favs[part] then Lift(ui.favs[part], true) end
            if (old == "logo") ~= (part == "logo") then LogoHover(part == "logo") end
            Tooltip(part)
            Launcher.Update()
        end
    end
    win:SetHandler("OnMouseEnter", function()
        ui.frame:SetFrameColor(C.gold, 1)
        hoverPart = nil
        Hover()
        B.EM:RegisterForUpdate("Skillbound_LauncherHover", 50, Hover)
    end)
    win:SetHandler("OnMouseExit", function()
        B.EM:UnregisterForUpdate("Skillbound_LauncherHover")
        ui.frame:SetFrameColor(C.goldDark, 1)
        if type(hoverPart) == "number" and ui.favs[hoverPart] then Lift(ui.favs[hoverPart], false) end
        if hoverPart == "logo" then LogoHover(false) end
        hoverPart = nil
        ClearTooltip(InformationTooltip)
        Launcher.Update()
    end)
    win:SetHandler("OnMouseDown", function(self, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then ui.pressX, ui.pressY = self:GetLeft(), self:GetTop() end
    end)
    win:SetHandler("OnMoveStart", function() ClearTooltip(InformationTooltip) end)
    win:SetHandler("OnMoveStop", function(self)
        B.sv.launcher.x, B.sv.launcher.y = self:GetLeft(), self:GetTop()
        Place()
    end)
    win:SetHandler("OnMouseUp", function(self, button, upInside)
        if not upInside then return end
        local part = PartUnderMouse()
        ClearTooltip(InformationTooltip)
        if button == MOUSE_BUTTON_INDEX_RIGHT then
            if type(part) == "number" then FavMenu(part) else MainMenu() end
            return
        end
        if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        local moved = ui.pressX and (math.abs(self:GetLeft() - ui.pressX) > 3 or math.abs(self:GetTop() - ui.pressY) > 3)
        ui.pressX, ui.pressY = nil, nil
        if moved then return end
        PlaySound(SOUNDS.DEFAULT_CLICK)
        if part == "arrow" then
            Launcher.Fold(not B.sv.launcher.folded)
            Tooltip("arrow")
        elseif type(part) == "number" then
            local b = B.Get(B.Char().fav[part])
            if b then
                Anim.Pulse(ui.favs[part].icon, 0.85, Anim.PRESS * 2)
                B.UI.AskWear(b)   -- ("Switch to ...?" unless turned off)
            else
                PickForSlot(part)
            end
        else
            LogoClicked()
            B.UI.Toggle()
        end
    end)

    -- warm light breathing behind the logo while a build is being put on; and until the
    -- logo has been clicked once, its amber ring breathes (shows new players where to click)
    win:SetHandler("OnUpdate", B.Safe(function()
        if not Anim.Enabled() then return end
        local t = GetFrameTimeSeconds()
        if ui.busy then
            ui.logoLight:SetAlpha(0.25 + 0.2 * math.sin(t * 5))
        end
        if not B.sv.launcher.clicked then
            ui.logoHalo:SetAlpha(math.max(0.4 * ui.logoHoverP, 0.08 + 0.17 * (0.5 + 0.5 * math.sin(t * 3))))
        end
    end, "button"))

    ui.fragment = B.HudFragment(win)
    inCombat = IsUnitInCombat("player")
    B.EM:RegisterForEvent("Skillbound_Launcher", EVENT_PLAYER_COMBAT_STATE, function(_, combat)
        inCombat = combat
        Launcher.Update()
    end)
    for _, name in ipairs({ "SettingsChanged", "BuildsChanged", "ApplyProgress", "RulesChanged" }) do
        B.callbacks:RegisterCallback(name, Launcher.Update)
    end
    B.callbacks:RegisterCallback("Worn", function()
        ui.busy = false
        ui.logoLight:SetAlpha(0)
        Launcher.Update()
        Anim.Pulse(ui.logo, 1.25, 420, "Skillbound_LauncherLogo")
    end)
    B.callbacks:RegisterCallback("PositionsReset", Place)
    -- the check (food running out, poisons, repairs) changes over time
    B.EM:RegisterForUpdate("Skillbound_LauncherCheck", 10000, Launcher.Update)
    Launcher.Update()
end
