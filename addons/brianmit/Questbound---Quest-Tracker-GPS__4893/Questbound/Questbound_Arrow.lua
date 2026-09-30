-- Questbound_Arrow.lua : the direction arrow and, as its own panel, the text
-- (objective, distance, time, progress on a plate that fades out at the ends).
-- Both can be moved (drag), resized (mouse wheel), locked, hidden and reset
-- (right-click), each on its own, with the mouse cursor shown.
--
-- Arrow designs: Textures/arrow_<id>.dds (picture), _mask (silhouette, used for
-- the shadow) and _glow. "Tinted" designs are grey and take the accent color;
-- the others keep their own colors.
-- Animations (sv.anim "full" / "subtle" / "off"): spin-in on a new objective,
-- glow when you face it, wrong-way nudge, arrival dip + ring.
--
-- sv.arrow.style "compact" (default since 0.10.0): the big arrow is off and the text
-- panel becomes a dark pill with a small badge (logo_fill + rim.dds + pointer.dds
-- turning, with animations: see UpdateBadge) left of the objective and distance. "classic": big arrow above centered text.

local W = Questbound
local L = W.L
local C = W.COLOR
local Arrow = {}
W.Arrow = Arrow

Arrow.DESIGNS = { "ornate", "dwemer", "rose", "blade", "medallion", "arrowhead",
    "outline", "triple", "daedric", "gem", "wisp", "banner" }
local OWN_COLORS = { blade = true, arrowhead = true, daedric = true, banner = true }

local ui = {}              -- arrow window
local tp = {}              -- text panel window
local angle = 0            -- shown rotation (smoothed)
local inCombat = false
local shown = {}           -- last texts set, to skip SetText every frame
local arrivedAt            -- time the arrival started (dip animation)
local info = {}            -- followed quest: type color, objectives done / total
local hint                 -- travel hint shown in the text (see ComputeHint), nil = none

local TEXT_W = 340         -- text panel width at scale 1
local PLATE_PAD_X = 34
local MIN_SIZE, MAX_SIZE = 28, 128
local MIN_SCALE, MAX_SCALE = 0.6, 1.8
local SPIN_TIME = 0.9      -- spin-in on a new objective
local FACING = math.rad(20)
local BADGE = 30           -- compact badge size at scale 1

local function Compact()
    return W.sv.arrow.style ~= "classic"
end


local function EaseOutBack(p)
    local c1 = 1.70158
    local q = p - 1
    return 1 + (c1 + 1) * q * q * q + c1 * q * q
end

local function Design()
    local d = W.sv.arrow.design
    for _, id in ipairs(Arrow.DESIGNS) do
        if id == d then return d end
    end
    return "ornate"
end

-- ---------------------------------------------------------------------------
-- Placement

local function PlaceArrow()
    local sv = W.sv.arrow
    ui.win:ClearAnchors()
    ui.win:SetAnchor(CENTER, GuiRoot, TOPLEFT, sv.x or GuiRoot:GetWidth() / 2, sv.y or 150)
end

-- text panel: its top center; by default right under the arrow
-- (compact look's standard spot: centered, TEXT_TOP of the screen height from the top)
local TEXT_TOP = 105 / 1080   -- (release layout: top at 105 on a 1080-high UI)
local function PlaceText()
    local a, s = W.sv.arrow, W.sv.label
    local compact = W.sv.arrow.style ~= "classic"
    local x = s.x or (not compact and a.x) or GuiRoot:GetWidth() / 2
    local y = s.y or (compact and zo_round(GuiRoot:GetHeight() * TEXT_TOP)) or ((a.y or 150) + a.size / 2 + 8)
    tp.win:ClearAnchors()
    tp.win:SetAnchor(TOP, GuiRoot, TOPLEFT, x, y)
end

local function Place()
    PlaceArrow()
    PlaceText()
end

-- ---------------------------------------------------------------------------
-- Text panel

-- Compact: the pill wraps badge + text; text left-aligned, centered in height.
local function FitPill()
    local s = W.sv.label.scale
    local nameOn = not tp.name:IsHidden() and not tp.nameGone and tp.name:GetText() ~= ""
    local infoOn = not tp.info:IsHidden() and tp.info:GetText() ~= ""
    local w, h = 0, 0
    if nameOn then
        w = math.max(w, tp.name:GetTextWidth())
        h = h + tp.name:GetTextHeight()
    end
    if infoOn then
        w = math.max(w, tp.info:GetTextWidth())
        h = h + tp.info:GetTextHeight() + (nameOn and 1 or 0)
    end
    local badge = BADGE * s
    local height = math.max(h, badge) + 12 * s
    local textX = 6 * s + badge + 9 * s
    local width = (w > 0) and (textX + w + 16 * s) or (badge + 12 * s)
    width = math.max(width, height)
    tp.pill:SetDimensions(width, height)
    tp.capL:SetDimensions(height / 2, height)
    tp.capR:SetDimensions(height / 2, height)
    local top = (height - h) / 2
    tp.name:ClearAnchors()
    tp.name:SetAnchor(TOPLEFT, tp.pill, TOPLEFT, textX, top)
    tp.info:ClearAnchors()
    if nameOn then
        tp.info:SetAnchor(TOPLEFT, tp.name, BOTTOMLEFT, 0, 1)
    else
        tp.info:SetAnchor(TOPLEFT, tp.pill, TOPLEFT, textX, top)
    end
end

-- Plate follows the text size.
local function FitPlate()
    if Compact() then return FitPill() end
    local w, h = 0, 0
    for _, label in ipairs({ tp.name, tp.info }) do
        if not label:IsHidden() and label:GetText() ~= "" then
            w = math.max(w, label:GetTextWidth())
            h = h + label:GetTextHeight() + 1
        end
    end
    local scale = W.sv.label.scale
    tp.plate:SetHidden(w == 0)
    tp.plate:SetDimensions(math.min((TEXT_W + 40) * scale, w + (PLATE_PAD_X * 2 + 16) * scale), h + 10 * scale)
end

local function SetText(label, text)
    if shown[label] ~= text then
        shown[label] = text
        label:SetText(text)
        FitPlate()
    end
end

-- Type color and objective progress of the followed quest (on quest updates).
function Arrow.RefreshQuestInfo()
    ZO_ClearTable(info)
    local qi = W.Nav.state.questIndex
    if not qi or not IsValidQuestIndex(qi) then return end
    local _, _, _, _, _, _, _, _, _, questType = GetJournalQuestInfo(qi)
    local repeatable = GetJournalQuestRepeatType and GetJournalQuestRepeatType(qi) ~= QUEST_REPEAT_NOT_REPEATABLE
    if W.Dungeon.Info(qi) then
        info.color = C.theme
    elseif questType == QUEST_TYPE_MAIN_STORY then
        info.color = C.story
    elseif repeatable then
        info.color = C.theme
    else
        info.color = C.quest
    end
    local done, total = 0, 0
    local _, _, _, _, numConditions = GetJournalQuestStepInfo(qi, 1)
    for cond = 1, numConditions or 0 do
        local text, _, _, isFail, isComplete, _, isVisible = GetJournalQuestConditionInfo(qi, 1, cond)
        if text and text ~= "" and not isFail and isVisible ~= false then
            total = total + 1
            if isComplete then done = done + 1 end
        end
    end
    info.done, info.total = done, total
end

-- ---------------------------------------------------------------------------
-- Apply settings

function Arrow.Apply()
    local sv, ls = W.sv.arrow, W.sv.label
    sv.size = zo_clamp(sv.size, MIN_SIZE, MAX_SIZE)
    ls.scale = zo_clamp(ls.scale, MIN_SCALE, MAX_SCALE)
    sv.design = Design()

    -- arrow
    local size = sv.size
    local base = W.TEX .. "arrow_" .. sv.design
    ui.body:SetTexture(base .. ".dds")
    ui.shadow:SetTexture(base .. "_mask.dds")
    ui.glow:SetTexture(base .. "_glow.dds")
    ui.holder:SetDimensions(size, size)
    ui.win:SetDimensions(size + 16, size + 16)
    ui.win:SetMovable(not sv.locked)
    local compact = Compact()
    W.ShowOnHud(ui.fragment, sv.shown and not compact)   -- compact: the arrow is the badge in the text

    -- text panel
    local scale = ls.scale
    tp.win:SetDimensions(TEXT_W * scale, 90 * scale)
    tp.win:SetMovable(not ls.locked)
    tp.name:SetFont(W.Font("quest", zo_round((compact and 15 or 17) * scale)))
    tp.info:SetFont(W.Font("title", zo_round((compact and 12 or 13) * scale)))
    local textW = compact and (TEXT_W - BADGE - 40) or (TEXT_W - PLATE_PAD_X)
    tp.name:SetWidth(textW * scale)
    tp.info:SetWidth(textW * scale)
    local align = compact and TEXT_ALIGN_LEFT or TEXT_ALIGN_CENTER
    tp.name:SetHorizontalAlignment(align)
    tp.info:SetHorizontalAlignment(align)
    tp.name:SetHidden(not sv.showName)
    tp.info:SetHidden(not sv.showDistance)
    tp.nameGone = nil
    if not compact then
        tp.name:ClearAnchors()
        tp.name:SetAnchor(TOP, tp.plate, TOP, 0, 5)
        tp.info:ClearAnchors()
        if sv.showName then
            tp.info:SetAnchor(TOP, tp.name, BOTTOM, 0, 1)
        else
            tp.info:SetAnchor(TOP, tp.plate, TOP, 0, 5 * scale)
        end
    end
    tp.dot:SetDimensions(8 * scale, 8 * scale)

    -- compact pill: dark body with round ends, badge with the turning marker
    tp.pill:SetHidden(not compact)
    local disc = W.TEX .. (W.TextureLoaded("disc.dds") and "disc.dds" or "dot.dds")
    for _, t in ipairs({ tp.capL, tp.capR }) do t:SetTexture(disc) end
    tp.capL:SetTextureCoords(0, 0.5, 0, 1)
    tp.capR:SetTextureCoords(0.5, 1, 0, 1)
    -- sketch 3 badge (dark disc, gold rim, hollow marker) once its images are loaded
    tp.newArt = W.TextureLoaded("rim.dds") and W.TextureLoaded("pointer.dds") and W.TextureLoaded("logo_fill.dds")
        and W.TextureLoaded("arc.dds")
    tp.badge:SetTexture(tp.newArt and (W.TEX .. "logo_fill.dds") or disc)
    tp.rim:SetTexture(W.TEX .. "rim.dds")
    tp.rim:SetHidden(not tp.newArt)
    tp.needle:SetTexture(W.TEX .. (tp.newArt and "pointer.dds" or "arrow.dds"))
    tp.ripple:SetTexture(W.TEX .. (tp.newArt and "rim.dds" or "ring.dds"))
    if tp.newArt then tp.check:SetColor(W.RGBA(C.done)) else tp.check:SetColor(0.12, 0.09, 0.05, 1) end
    tp.badge:SetDimensions(BADGE * scale, BADGE * scale)
    tp.needle:SetDimensions(BADGE * (tp.newArt and 1 or 0.62) * scale, BADGE * (tp.newArt and 1 or 0.62) * scale)
    tp.check:SetDimensions(BADGE * 0.55 * scale, BADGE * 0.55 * scale)
    tp.badge:SetHidden(not sv.shown)
    tp.badge:ClearAnchors()
    tp.badge:SetAnchor(LEFT, tp.pill, LEFT, 6 * scale, 0)

    -- background: "lines" (text with a soft shadow between two gold lines, default),
    -- "dark" (dark haze behind), "none" (text only)
    local bg = ls.bg or "lines"
    tp.haze:SetHidden(compact or bg ~= "dark" or not W.TextureLoaded("plate.dds"))
    tp.haze:SetColor(0, 0, 0, 0.6)
    for _, line in ipairs(tp.lines) do line:SetHidden(compact or bg == "none") end
    ZO_ClearTable(shown)   -- fonts changed: set the texts again
    FitPlate()
    W.ShowOnHud(tp.fragment, ls.shown)
    Place()
end

-- ---------------------------------------------------------------------------
-- Comfort: drag, wheel, right-click menu (same for the arrow and the text)

local function Resize(which, delta)
    if which == "arrow" then
        W.sv.arrow.size = zo_clamp(zo_round(W.sv.arrow.size + delta * 4), MIN_SIZE, MAX_SIZE)
    else
        W.sv.label.scale = zo_clamp(W.sv.label.scale + delta * 0.05, MIN_SCALE, MAX_SCALE)
    end
    Arrow.Apply()
end

local function NextDesign()
    local sv = W.sv.arrow
    local list = Arrow.DESIGNS
    local n = 1
    for i, id in ipairs(list) do
        if id == sv.design then n = i end
    end
    sv.design = list[n % #list + 1]
    Arrow.Apply()
end

local function Menu(which)
    local s = which == "arrow" and W.sv.arrow or W.sv.label
    ClearMenu()
    AddMenuItem(L(s.locked and "MENU_UNLOCK" or "MENU_LOCK"), function()
        s.locked = not s.locked
        Arrow.Apply()
    end)
    AddMenuItem(L("MENU_BIGGER"), function() Resize(which, 2) end)
    AddMenuItem(L("MENU_SMALLER"), function() Resize(which, -2) end)
    if which == "arrow" then
        AddMenuItem(L("MENU_DESIGN", L("DESIGN_" .. zo_strupper(Design()))), NextDesign)
    end
    -- compact pill <-> big arrow above the text
    AddMenuItem(L("MENU_ARROW_STYLE", L(Compact() and "SET_ARROW_STYLE_COMPACT" or "SET_ARROW_STYLE_CLASSIC")), function()
        W.sv.arrow.style = Compact() and "classic" or "compact"
        Arrow.Apply()
    end)
    AddMenuItem(L("MENU_RESET_POS"), function()
        s.x, s.y = nil, nil
        if which == "arrow" then s.size = 56 else s.scale = 1 end
        Arrow.Apply()
    end)
    if which == "arrow" then
        AddMenuItem(L("MENU_HIDE_ARROW"), function() W.ToggleArrow() end)
    else
        AddMenuItem(L("MENU_HIDE_TEXT"), function() W.ToggleText() end)
    end
    ShowMenu(which == "arrow" and ui.win or tp.win)
end

local function Comfort(win, which)
    win:SetClampedToScreen(true)
    win:SetMouseEnabled(true)
    win:SetHandler("OnMoveStop", function(self)
        local s = which == "arrow" and W.sv.arrow or W.sv.label
        if which == "arrow" then
            s.x, s.y = self:GetCenter()
        else
            s.x, s.y = (self:GetLeft() + self:GetRight()) / 2, self:GetTop()
        end
        Place()
    end)
    win:SetHandler("OnMouseDown", function(self, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then self.pressX, self.pressY = self:GetLeft(), self:GetTop() end
    end)
    win:SetHandler("OnMouseUp", function(self, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_RIGHT then Menu(which) end
        -- a click (not a drag) on the text: take the travel hint, when one is shown
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT and which == "text" and self.pressX
            and math.abs(self:GetLeft() - self.pressX) + math.abs(self:GetTop() - self.pressY) < 3 then
            Arrow.TextClicked()
        end
        self.pressX, self.pressY = nil, nil
    end)
    win:SetHandler("OnMouseWheel", function(_, delta)
        local s = which == "arrow" and W.sv.arrow or W.sv.label
        if not s.locked then Resize(which, delta) end
    end)
    win:SetHandler("OnMouseEnter", function(self)
        local s = which == "arrow" and W.sv.arrow or W.sv.label
        InitializeTooltip(InformationTooltip, self, TOP, 0, 4, BOTTOM)
        local text = L(s.locked and "TT_MOVE_LOCKED" or "TT_MOVE")
        if which == "text" and hint and not hint.info then
            local key = (hint.queue and "TT_QUEUE_CLICK") or (hint.pvp and "TT_PVP_CLICK") or "TT_TRAVEL"
            text = L(key) .. "\n" .. text
        end
        SetTooltipText(InformationTooltip, text)
    end)
    win:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
end

-- ---------------------------------------------------------------------------
-- Init

local function Tex(parent, file)
    local t = WINDOW_MANAGER:CreateControl(nil, parent, CT_TEXTURE)
    if file then t:SetTexture(W.TEX .. file) end
    return t
end

function Arrow.Init()
    -- arrow window
    local win = WINDOW_MANAGER:CreateTopLevelWindow("Questbound_Arrow")
    ui.win = win
    -- DL_CONTROLS: above the ground line's 3D pictures (DL_BACKGROUND drew them over the text)
    win:SetDrawLayer(DL_CONTROLS)
    Comfort(win, "arrow")
    ui.box = WINDOW_MANAGER:CreateControl(nil, win, CT_CONTROL)
    ui.box:SetAnchorFill(win)
    ui.box:SetHidden(true)
    local holder = WINDOW_MANAGER:CreateControl(nil, ui.box, CT_CONTROL)
    ui.holder = holder
    holder:SetAnchor(CENTER, ui.box, CENTER, 0, 0)
    local function ArrowTex(level)
        local t = Tex(holder)
        t:SetAnchor(CENTER, holder, CENTER, 0, 0)
        t:SetDrawLevel(level)
        return t
    end
    ui.glow = ArrowTex(1)
    ui.glow:SetAlpha(0)
    ui.shadow = ArrowTex(2)
    ui.shadow:SetColor(0, 0, 0, 0.5)
    ui.body = ArrowTex(3)
    ui.ring = ArrowTex(3)
    ui.ring:SetTexture(W.TEX .. "ring.dds")
    ui.ring:SetHidden(true)
    ui.fragment = W.HudFragment(win)

    -- text panel window
    local twin = WINDOW_MANAGER:CreateTopLevelWindow("Questbound_Text")
    tp.win = twin
    twin:SetDrawLayer(DL_CONTROLS)
    Comfort(twin, "text")
    tp.box = WINDOW_MANAGER:CreateControl(nil, twin, CT_CONTROL)
    tp.box:SetAnchorFill(twin)
    tp.box:SetHidden(true)

    -- plate: dark strip fading out at the ends, gold line above and below
    -- plate: invisible holder for the gold lines; the dark haze is a separate
    -- picture that's only shown with the "Dark" background (T1 = text + lines only)
    tp.plate = WINDOW_MANAGER:CreateControl(nil, tp.box, CT_CONTROL)
    tp.plate:SetAnchor(TOP, tp.box, TOP, 0, 0)
    tp.haze = Tex(tp.plate, "plate.dds")
    tp.haze:SetAnchorFill(tp.plate)
    tp.haze:SetDrawLevel(0)
    tp.lines = {}
    for _, side in ipairs({ TOP, BOTTOM }) do
        local line = Tex(tp.plate, "divider.dds")
        tp.lines[#tp.lines + 1] = line
        line:SetColor(W.RGBA(C.gold))
        line:SetHeight(10)
        line:SetDrawLevel(1)
        line:SetAnchor(LEFT, tp.plate, side == TOP and TOPLEFT or BOTTOMLEFT, 0, 0)
        line:SetAnchor(RIGHT, tp.plate, side == TOP and TOPRIGHT or BOTTOMRIGHT, 0, 0)
    end

    -- compact pill (see FitPill): left half disc + middle strip + right half disc,
    -- badge on the left with the turning marker (or a check on arrival); the halo and
    -- the arrival ripple are the pill's children around the badge (see UpdateBadge)
    tp.pill = WINDOW_MANAGER:CreateControl(nil, tp.box, CT_CONTROL)
    tp.pill:SetAnchor(TOP, tp.box, TOP, 0, 0)
    tp.capL = Tex(tp.pill)
    tp.capL:SetAnchor(TOPLEFT, tp.pill, TOPLEFT, 0, 0)
    tp.capR = Tex(tp.pill)
    tp.capR:SetAnchor(TOPRIGHT, tp.pill, TOPRIGHT, 0, 0)
    tp.mid = Tex(tp.pill)
    tp.mid:SetAnchor(TOPLEFT, tp.capL, TOPRIGHT, 0, 0)
    tp.mid:SetAnchor(BOTTOMRIGHT, tp.capR, BOTTOMLEFT, 0, 0)
    for _, t in ipairs({ tp.capL, tp.capR, tp.mid }) do
        t:SetColor(0, 0, 0, 0.5)
        t:SetDrawLevel(0)
    end
    tp.badge = Tex(tp.pill)
    tp.badge:SetAnchor(LEFT, tp.pill, LEFT, 6, 0)
    tp.badge:SetDrawLevel(2)
    tp.glow = Tex(tp.pill, "dot.dds")          -- b: halo while facing the objective
    tp.glow:SetAnchor(CENTER, tp.badge, CENTER, 0, 0)
    tp.glow:SetDrawLevel(1)
    tp.glow:SetHidden(true)
    tp.rim = Tex(tp.badge, "rim.dds")
    tp.rim:SetAnchorFill(tp.badge)
    tp.rim:SetDrawLevel(3)
    tp.arc = Tex(tp.badge, "arc.dds")          -- 1: wrong-way turn signal on the rim
    tp.arc:SetAnchorFill(tp.badge)
    tp.arc:SetDrawLevel(4)
    tp.arc:SetHidden(true)
    tp.needle = Tex(tp.badge, "arrow.dds")
    tp.needle:SetAnchor(CENTER, tp.badge, CENTER, 0, 0)
    tp.needle:SetColor(0.12, 0.09, 0.05, 1)
    tp.needle:SetDrawLevel(4)
    tp.check = Tex(tp.badge, "check.dds")
    tp.check:SetAnchor(CENTER, tp.badge, CENTER, 0, 0)
    tp.check:SetColor(0.12, 0.09, 0.05, 1)
    tp.check:SetDrawLevel(4)
    tp.check:SetHidden(true)
    tp.ripple = Tex(tp.pill, "rim.dds")        -- d: ring rippling out on arrival
    tp.ripple:SetAnchor(CENTER, tp.badge, CENTER, 0, 0)
    tp.ripple:SetDrawLevel(3)
    tp.ripple:SetHidden(true)
    -- quest in another zone (no direction to point): the game's wayshrine icon in the badge
    tp.away = WINDOW_MANAGER:CreateControl(nil, tp.badge, CT_TEXTURE)
    tp.away:SetTexture("EsoUI/Art/Icons/poi/poi_wayshrine_complete.dds")
    tp.away:SetAnchor(CENTER, tp.badge, CENTER, 0, 0)
    tp.away:SetDrawLevel(4)
    tp.away:SetHidden(true)
    tp.pill:SetHidden(true)

    tp.name = WINDOW_MANAGER:CreateControl(nil, tp.box, CT_LABEL)
    tp.name:SetAnchor(TOP, tp.plate, TOP, 0, 5)
    tp.name:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    tp.name:SetMaxLineCount(3)
    tp.name:SetColor(1, 1, 1, 1)
    tp.name:SetDrawLevel(2)

    tp.dot = Tex(tp.box, "dot.dds")   -- quest type dot in front of the objective name
    tp.dot:SetDrawLevel(2)

    tp.info = WINDOW_MANAGER:CreateControl(nil, tp.box, CT_LABEL)
    tp.info:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    tp.info:SetDrawLevel(2)
    tp.fragment = W.HudFragment(twin)

    EVENT_MANAGER:RegisterForEvent("Questbound_Arrow", EVENT_PLAYER_COMBAT_STATE, function(_, combat)
        inCombat = combat
    end)
    inCombat = IsUnitInCombat("player")
    W.callbacks:RegisterCallback("SettingsChanged", Arrow.Apply)
    W.callbacks:RegisterCallback("PositionsReset", Arrow.Apply)   -- (also the standard text size)
    W.callbacks:RegisterCallback("QuestsChanged", Arrow.RefreshQuestInfo)
    W.callbacks:RegisterCallback("TargetChanged", Arrow.RefreshQuestInfo)
    Arrow.Apply()
end

function Arrow.DebugText()
    local x, y = ui.holder:GetCenter()
    return string.format("arrow: window hidden %s, box hidden %s, at %.0f,%.0f, design %s, text '%s'",
        tostring(ui.win:IsHidden()), tostring(ui.box:IsHidden()), x or -1, y or -1,
        Design(), tp.name:GetText())
end

-- ---------------------------------------------------------------------------
-- Per frame

-- Text when the followed quest has no position here because it's in another zone.
local function Elsewhere(qi)
    if not qi or not IsValidQuestIndex(qi) then return nil end
    local zoneName, _, zoneIndex = GetJournalQuestLocationInfo(qi)
    if not zoneIndex or zoneIndex == GetUnitZoneIndex("player") or not zoneName or zoneName == "" then return nil end
    local queue, dungeon = W.Dungeon.NeedsQueue(qi)
    if queue then return L("ARROW_DUNGEON", dungeon.name) end
    if W.Dungeon.IsPvPQuest(qi) then return L("ARROW_PVP", zo_strformat("<<1>>", zoneName)) end
    -- real destination: the journal's place in that zone too ("Orsinium, Wrothgar")
    return L("ARROW_ELSEWHERE", W.Nav.DestinationName(qi) or zo_strformat("<<1>>", zoneName))
end

local HEX_DIM, HEX_DONE = "8E8C86", "7DB87D"

local function SetArrowSize(scale)
    local s = W.sv.arrow.size * scale
    ui.body:SetDimensions(s, s)
    ui.shadow:SetDimensions(s, s)
    ui.glow:SetDimensions(s * 1.45, s * 1.45)
end

local function SetRotation(a)
    ui.body:SetTextureRotation(a)
    ui.shadow:SetTextureRotation(a)
    ui.glow:SetTextureRotation(a)
end

local function ShowArrowParts(show)
    ui.body:SetHidden(not show)
    ui.shadow:SetHidden(not show)
    ui.glow:SetHidden(not show)
end

-- ---------------------------------------------------------------------------
-- Travel hint (every 2 s): a known wayshrine on this map much closer to the objective
-- than you ("Faster: travel to X, saves 1.2 km"), or, for a quest in another zone,
-- "click to travel there". A click on the text panel then offers the travel.
local HINT_EVERY = 2
local SAVE_MIN_M = 600     -- only when walking this much less
local hintAt = 0

-- Do you know (have discovered) a wayshrine in this zone? Travel is only offered
-- then. Checked at most every 30 s per zone.
local knownIn = {}
local function KnowsWayshrineIn(zoneIndex)
    if not GetFastTravelNodePOIIndicies then return true end
    local now = GetFrameTimeSeconds()
    local c = knownIn[zoneIndex]
    if c and now - c.t < 30 then return c.v end
    local v = false
    for i = 1, GetNumFastTravelNodes() do
        local known, _, _, _, _, _, poiType, _, locked = GetFastTravelNodeInfo(i)
        if known and not locked and poiType == POI_TYPE_WAYSHRINE and GetFastTravelNodePOIIndicies(i) == zoneIndex then
            v = true
            break
        end
    end
    knownIn[zoneIndex] = { t = now, v = v }
    return v
end

-- Quest in another zone: "Faster: click to travel to <wayshrine>", only when the
-- wayshrine nearest its objective is one you've discovered (background lookup,
-- Teleport.NearestKnown); nil = no line at all.
local function TravelHint(qi, questZone)
    if not questZone or questZone <= 0 or not KnowsWayshrineIn(questZone) then return nil end
    local r = W.Teleport.NearestKnown(qi)
    if not r then return nil end
    return { node = r.node, name = r.name, dist = r.dist, qi = qi,
        text = W.Colorize(C.theme, L("TRAVEL_TO_ZONE", r.name)) }
end

local function ComputeHint(nav, t, elsewhere)
    hint = nil
    local qi = nav.questIndex
    -- group dungeon quest you're not in: click the text to queue (dungeon icon in the
    -- badge); always offered, like the tracker's queue icon
    if qi and W.Dungeon.NeedsQueue(qi) then
        hint = { queue = true, qi = qi, text = W.Colorize(C.theme, L("QUEUE_CLICK")) }
        return
    end
    -- PvP quest (Cyrodiil / Imperial City) while you're elsewhere: click to join your
    -- home campaign (Alliance War icon in the badge)
    if not t and elsewhere and qi and W.Dungeon.IsPvPQuest(qi) and not IsInAvAZone() then
        local home = W.Dungeon.HomeCampaignName()
        local text = home ~= "" and L("PVP_JOIN", home) or L("PVP_PICK")
        hint = { pvp = true, qi = qi, text = W.Colorize(C.theme, text) }
        return
    end
    if not W.sv.arrow.travelHint or IsInAvAZone() or IsUnitInCombat("player") then return end
    if not t then
        if elsewhere and qi and not W.Dungeon.IsPvPQuest(qi) then
            local _, _, questZone = GetJournalQuestLocationInfo(qi)
            hint = TravelHint(qi, questZone)
        end
        return
    end
    -- "next area" toward another zone (the marker only leads to the road / boat out):
    -- offer to travel straight to the wayshrine nearest the quest in that zone.
    -- Not for leaving a delve / city into its own zone (same zone or its parent).
    if t.other and qi and not W.Dungeon.IsPvPQuest(qi) then
        local _, _, questZone = GetJournalQuestLocationInfo(qi)
        if questZone and questZone > 0 then
            local questId = GetZoneId(questZone)
            local myId = GetZoneId(GetUnitZoneIndex("player"))
            local myParent = GetParentZoneId(myId)
            if questId ~= myId and questId ~= myParent and GetParentZoneId(questId) ~= myId then
                hint = TravelHint(qi, questZone)
            end
        end
        return
    end
    local cal = nav.cal
    if t.other or not nav.dist or not cal or not cal.s then return end
    local best, bestD
    for i = 1, GetNumFastTravelNodes() do
        local known, name, x, y, _, _, poiType, shown, locked = GetFastTravelNodeInfo(i)
        if known and shown and not locked and poiType == POI_TYPE_WAYSHRINE then
            local d = math.sqrt((x - t.x) ^ 2 + (y - t.y) ^ 2) * cal.s / 100   -- map units -> m
            if not bestD or d < bestD then
                best, bestD = { node = i, name = zo_strformat("<<1>>", name) }, d
            end
        end
    end
    if best and nav.dist - bestD >= SAVE_MIN_M and bestD <= nav.dist * 0.5 then
        best.dist, best.qi = bestD, qi
        best.text = W.Colorize(C.theme, L("TRAVEL_FASTER", best.name, W.FormatDistance(nav.dist - bestD)))
        hint = best
    end
end

function Arrow.TextClicked()
    local h = hint
    if not h or h.info then return end   -- (info = a note only, nothing to click)
    PlaySound(SOUNDS.DEFAULT_CLICK)
    ClearTooltip(InformationTooltip)
    if h.queue then
        W.Dungeon.Offer(h.qi)
    elseif h.pvp then
        W.Dungeon.JoinPvP(h.qi)
    elseif h.zone then
        W.Teleport.Start(h.qi)
    else
        W.Teleport.OfferNode(h.node, h.name, h.dist, W.Nav.state.questName)
    end
end

local function UpdateText(nav, t, elsewhere, since, fadeAlpha)
    local sv = W.sv.arrow
    local theme = C.theme
    local nameText, infoText = "", ""
    if not t then
        nameText = sv.showName and (nav.questName or "") or ""
        infoText = W.Colorize(theme, elsewhere)
    else
        if sv.showName then
            nameText = t.text or t.name or ""
            local queue, dungeon = W.Dungeon.NeedsQueue(nav.questIndex)
            if t.kind == "quest" and queue then
                nameText = nameText .. "\n" .. W.Colorize(theme, L("ARROW_DUNGEON", dungeon.name))
            elseif t.other then
                -- "next area": say where it leads (the journal's place / zone for the quest)
                local dest = W.Nav.DestinationName(nav.questIndex)
                local line = dest and L(t.door and "THROUGH_DOOR_TO" or "NEXT_AREA_TO", dest) or L("OTHER_MAP")
                nameText = nameText .. "\n|c" .. HEX_DIM .. line .. "|r"
            end
        end
        if nav.arrived then
            infoText = "|c" .. HEX_DONE .. L("ARRIVED") .. "|r"
        elseif nav.dist then
            infoText = W.Colorize(theme, W.FormatDistance(nav.dist))
            -- on another floor (the compass says so): tell which way
            if nav.targetLevel == "above" or nav.targetLevel == "below" then
                local up = nav.targetLevel == "above"
                -- no walked way up / down yet: say what to look for
                local key = nav.needStairs and (up and "FIND_STAIRS_UP" or "FIND_STAIRS_DOWN")
                    or (up and "LEVEL_ABOVE" or "LEVEL_BELOW")
                infoText = infoText .. "  " .. W.Colorize(theme, L(key))
            end
            if t.kind == "quest" and info.total and info.total > 1 then
                infoText = infoText .. " |c" .. HEX_DIM .. "·  " .. L("ARROW_PROGRESS", info.done, info.total) .. "|r"
            end
        else
            infoText = "|c" .. HEX_DIM .. L("CALIBRATING") .. "|r"
        end
    end
    -- faster by wayshrine / travel to the quest's zone: one more line, click the text for it
    if hint and not nav.arrived then infoText = infoText .. "\n" .. hint.text end
    SetText(tp.name, nameText)
    SetText(tp.info, sv.showDistance and infoText or "")

    -- quest type dot, left of the name's first line (classic only: compact has the badge)
    local compact = Compact()
    local dotColor = not compact and t and t.kind == "quest" and info.color
    -- (only for one-line names: centered text makes the first line's edge unknown)
    tp.dot:SetHidden(not (sv.showName and dotColor and nameText ~= "" and not nameText:find("\n")))
    if dotColor then
        tp.dot:SetColor(W.RGBA(dotColor))
        tp.dot:ClearAnchors()
        local firstLineW = math.min(tp.name:GetTextWidth(), tp.name:GetWidth())
        tp.dot:SetAnchor(RIGHT, tp.name, TOP, -firstLineW / 2 - 5, tp.name:GetFontHeight() / 2)
    end

    -- (0.13.1: the "quiet" mode that faded the name out after 5 s was removed on
    -- request: the objective name always stays)
    tp.name:SetAlpha(fadeAlpha)
    tp.dot:SetAlpha(fadeAlpha)
    tp.info:SetAlpha(fadeAlpha)
    tp.plate:SetAlpha(fadeAlpha)
    tp.pill:SetAlpha(fadeAlpha)
end

-- Compact badge (arrow sketch 3): dark disc, gold rim, hollow quest marker turning
-- toward the objective; orange when it's behind you (color by angle), faint without
-- a direction (quest elsewhere). Before a game restart (new images not loaded): the
-- old gold disc with a dark arrow.
-- Animations (sv.arrow.fx, all off with sv.anim "off"):
--   spin   a: spins in and settles on a new objective (full only)
--   glow   b: soft halo pulsing behind the badge while you face the objective
--   arrive d: marker twirls away, check pops in, green ring ripples out (ripple: full only)
--   turn   1: objective behind you: a bright arc (arc.dds) runs along the rim from the
--             top toward the side to turn, again and again (subtle: stands at that side)
local TURN_ANGLE = math.rad(100)   -- "behind you" from this angle on
local TURN_SWEEP = math.rad(120)   -- how far the arc runs round the rim
local badgeArrivedAt
local glowA = 0
local turnA = 0

local function FxOn(key)
    if W.sv.anim == "off" then return false end
    local fx = W.sv.arrow.fx
    return not fx or fx[key] ~= false
end

local function SetBadgeColor(r, g, b, a)
    if tp.newArt then
        tp.badge:SetColor(0.10, 0.08, 0.06, a)
        tp.rim:SetColor(r, g, b, a)
        tp.needle:SetColor(r, g, b, a)
    else
        tp.badge:SetColor(r, g, b, a)
        tp.needle:SetColor(0.12, 0.09, 0.05, a)
    end
end

local function UpdateBadge(nav, t, now, dt)
    if tp.badge:IsHidden() then
        tp.glow:SetHidden(true)
        tp.ripple:SetHidden(true)
        return
    end
    local size = BADGE * W.sv.label.scale
    local full = W.sv.anim == "full"
    local theme = C.theme
    if not t or nav.arrived then
        turnA = 0
        tp.arc:SetHidden(true)
    end

    if not t then
        tp.glow:SetHidden(true)
        tp.ripple:SetHidden(true)
        tp.check:SetHidden(true)
        tp.needle:SetHidden(true)
        -- in another zone: a wayshrine icon in a gold-rimmed badge ("travel there"),
        -- faint when travel isn't offered (dungeon queue / PvP / hint turned off)
        local travel = hint ~= nil and not hint.info
        -- a group dungeon to queue for: the Group Finder's dungeon icon instead
        -- (a PvP campaign to join: the Alliance War icon)
        local icon = "EsoUI/Art/Icons/poi/poi_wayshrine_complete.dds"
        if hint and hint.queue then icon = W.Dungeon.ICON elseif hint and hint.pvp then icon = W.Dungeon.PVP_ICON end
        tp.away:SetTexture(icon)
        SetBadgeColor(theme.r, theme.g, theme.b, travel and 1 or 0.5)
        tp.away:SetDimensions(size * 0.72, size * 0.72)
        tp.away:SetAlpha(travel and 1 or 0.5)
        tp.away:SetHidden(false)
        badgeArrivedAt = nil
        return
    end
    tp.away:SetHidden(true)

    -- d: arrival
    if nav.arrived then
        badgeArrivedAt = badgeArrivedAt or now
        local a = now - badgeArrivedAt
        local done = C.done
        local fx = FxOn("arrive")
        SetBadgeColor(done.r, done.g, done.b, 1)
        tp.glow:SetHidden(true)
        if fx and a < 0.5 then
            local p = a / 0.5
            tp.needle:SetHidden(false)
            tp.needle:SetTextureRotation(angle + p * math.pi)
            local ns = size * (tp.newArt and 1 or 0.62) * (1 - 0.8 * p)
            tp.needle:SetDimensions(ns, ns)
            tp.needle:SetAlpha(1 - p)
        else
            tp.needle:SetHidden(true)
        end
        local cp = fx and zo_clamp((a - 0.3) / 0.25, 0, 1) or 1
        tp.check:SetHidden(cp <= 0)
        tp.check:SetAlpha(cp)
        local cs = size * 0.55 * (fx and (0.6 + 0.4 * EaseOutBack(cp)) or 1)
        tp.check:SetDimensions(cs, cs)
        if fx and full then
            local pulse = (a / 1.5) % 1
            local rs = size * (1 + 0.7 * pulse)
            tp.ripple:SetDimensions(rs, rs)
            tp.ripple:SetColor(done.r, done.g, done.b, 0.9 * (1 - pulse))
            tp.ripple:SetHidden(false)
        else
            tp.ripple:SetHidden(true)
        end
        return
    end
    badgeArrivedAt = nil
    tp.ripple:SetHidden(true)
    tp.check:SetHidden(true)
    tp.needle:SetHidden(false)
    tp.needle:SetAlpha(1)

    -- colors: accent when facing it, orange behind you
    local f = 0
    if W.sv.arrow.colorByAngle then
        f = zo_clamp((math.abs(nav.rel) / math.pi - 0.15) / 0.45, 0, 1)
        f = f * f * (3 - 2 * f)
    end
    local r, g, b = zo_lerp(theme.r, C.warn.r, f), zo_lerp(theme.g, C.warn.g, f), zo_lerp(theme.b, C.warn.b, f)
    SetBadgeColor(r, g, b, 1)

    -- a: spin-in on a new objective
    local since = now - (nav.targetSince or 0)
    local extra, scale = 0, 1
    if full and FxOn("spin") and since < SPIN_TIME then
        local e = EaseOutBack(since / SPIN_TIME)
        extra = (1 - e) * -3.5
        scale = 0.3 + 0.7 * e
    end
    local rot = angle + extra
    tp.needle:SetTextureRotation(rot)
    -- (1.0.1: the "nudge when close" animation was removed on request: the marker stays
    -- still in its badge)
    local ns = size * (tp.newArt and 1 or 0.62) * scale
    tp.needle:SetDimensions(ns, ns)
    local dx, dy = 0, 0
    tp.needle:ClearAnchors()
    tp.needle:SetAnchor(CENTER, tp.badge, CENTER, dx, dy)

    -- b: halo while you face it (eased in and out)
    local want = 0
    if FxOn("glow") and math.abs(nav.rel) < FACING then
        want = full and (0.4 + 0.25 * math.sin(now * 3)) or 0.4
    end
    glowA = glowA + (want - glowA) * math.min(1, (dt or 0) * 6)
    tp.glow:SetHidden(glowA < 0.01)
    tp.glow:SetDimensions(size * 1.7, size * 1.7)
    tp.glow:SetColor(r, g, b, glowA)

    -- 1: turn signal while the objective is behind you (rel > 0 = turn left, CCW)
    local behind = tp.newArt and FxOn("turn") and math.abs(nav.rel) > TURN_ANGLE
    turnA = turnA + ((behind and 1 or 0) - turnA) * math.min(1, (dt or 0) * 8)
    if turnA < 0.01 then
        tp.arc:SetHidden(true)
    else
        local side = nav.rel > 0 and 1 or -1
        local sweep, a = TURN_SWEEP / 2, 1
        if full then
            local p = (now * 0.8) % 1                -- one run every 1.25 s
            sweep, a = p * TURN_SWEEP, math.sin(p * math.pi)
        end
        tp.arc:SetTextureRotation(side * sweep)
        -- a lighter shade of the rim's color, so it reads as light running along it
        tp.arc:SetColor(zo_lerp(r, 1, 0.55), zo_lerp(g, 1, 0.55), zo_lerp(b, 1, 0.55), turnA * a)
        tp.arc:SetHidden(false)
    end
end

function Arrow.Update(nav, dt, now)
    if not ui.win or not nav.valid then return end
    local sv = W.sv.arrow
    local anim = W.sv.anim
    local theme = C.theme
    local t = nav.target
    local elsewhere = not t and Elsewhere(nav.questIndex)
    local show = (t ~= nil or elsewhere ~= nil) and not (sv.hideInCombat and inCombat)
    ui.box:SetHidden(not show or not t)          -- no arrow when the quest is elsewhere
    tp.box:SetHidden(not show)
    if not show then return end

    local since = now - (nav.targetSince or 0)
    local fadeAlpha = (W.sv.combatFade and inCombat) and 0.3 or 1

    -- rotation, eased so it doesn't jitter
    if t and nav.rel then
        local diff = W.Nav.WrapAngle(nav.rel - angle)
        angle = W.Nav.WrapAngle(angle + diff * math.min(1, dt * 12))
    end

    if not tp.win:IsHidden() then
        if now - hintAt > HINT_EVERY then
            hintAt = now
            ComputeHint(nav, t, elsewhere)
        end
        UpdateText(nav, t, elsewhere, since, fadeAlpha)
        if Compact() then UpdateBadge(nav, t, now, dt) end
    end
    if not t or ui.win:IsHidden() then return end
    local extra, scale = 0, 1
    if anim == "full" and since < SPIN_TIME then
        local e = EaseOutBack(since / SPIN_TIME)
        extra = (1 - e) * -3.5        -- spins in from the side
        scale = 0.3 + 0.7 * e
    end
    if anim == "full" and math.abs(nav.rel) > math.rad(110) then
        extra = extra + math.sin(now * 9) * 0.12   -- wrong way: nudge
    end

    -- colors: accent (or the design's own colors) when facing it, orange-red behind you
    local f = 0
    if sv.colorByAngle then
        f = zo_clamp((math.abs(nav.rel) / math.pi - 0.15) / 0.45, 0, 1)
        f = f * f * (3 - 2 * f)
    end
    local r, g, b
    if OWN_COLORS[Design()] then
        r, g, b = 1, zo_lerp(1, 0.55, f), zo_lerp(1, 0.45, f)
    else
        r, g, b = zo_lerp(theme.r, C.warn.r, f), zo_lerp(theme.g, C.warn.g, f), zo_lerp(theme.b, C.warn.b, f)
    end

    -- arrival: arrow dips and fades, a ring bursts out again and again
    if nav.arrived then
        arrivedAt = arrivedAt or now
    else
        arrivedAt = nil
    end
    if arrivedAt then
        local a = now - arrivedAt
        if anim ~= "off" and a < 0.6 then
            local p = a / 0.6
            ShowArrowParts(true)
            SetRotation(angle + p * math.pi)
            SetArrowSize(1 - 0.4 * p)
            ui.body:SetColor(r, g, b, 1 - p)
            ui.shadow:SetAlpha(1 - p)
            ui.glow:SetAlpha(0)
        else
            ShowArrowParts(false)
        end
        ui.ring:SetHidden(false)
        local pulse = (a * (anim == "off" and 0 or 0.9)) % 1
        local s = sv.size * (0.5 + 0.9 * pulse)
        ui.ring:SetDimensions(s, s)
        ui.ring:SetColor(C.done.r, C.done.g, C.done.b, anim == "off" and 1 or (1 - pulse))
    else
        ui.ring:SetHidden(true)
        ShowArrowParts(true)
        ui.shadow:SetAlpha(1)
        SetArrowSize(scale)
        SetRotation(angle + extra)
        ui.body:SetColor(r, g, b, 1)
        -- glow breathes while you face it
        local glow = 0
        if anim ~= "off" and math.abs(nav.rel) < FACING then
            glow = (anim == "full") and (0.35 + 0.3 * math.sin(now * 3)) or 0.35
        end
        local gc = OWN_COLORS[Design()] and C.theme or { r = r, g = g, b = b }
        ui.glow:SetColor(gc.r, gc.g, gc.b, 1)
        ui.glow:SetAlpha(glow)
    end
end
