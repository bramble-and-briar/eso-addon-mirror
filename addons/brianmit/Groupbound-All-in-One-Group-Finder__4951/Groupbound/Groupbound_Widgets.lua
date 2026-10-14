-- Groupbound_Widgets.lua : building blocks made from the game's own templates (layout A, picked
-- 2026-10-12: "like part of the game"), all read from esoui "live":
--   ZO_DefaultButton             the game's large button (buttontemplates.xml)
--   ZO_CheckButton               the game's checkbox (+ ZO_CheckButton_SetLabelText / _SetToggleFunction)
--   ZO_SingleLineEditBackdrop_Keyboard + ZO_DefaultEditForBackdrop   the game's search / text field
--   ZO_EditBackdrop + ZO_DefaultEditMultiLineForBackdrop             multi-line field
--   ZO_DynamicHorizontalDivider  the game's stretchable divider (windowtemplates.xml)
--   ZO_ListEntryHighlight        the game's list highlight (zo_listentrytemplates.xml), alpha 0 = hidden
--   ZO_ThinListBgStrip           the game's list row stripe (social_list_bgStrip.dds)
--   ZO_DefaultBackdrop           the game's dark window backdrop
-- Text uses the game's font objects (ZoFontGame, ZoFontHeader2...) and colors (ZO_NORMAL_TEXT...).

local G = Groupbound
local C = G.COLOR
local Anim = G.Anim
local W = {}
G.W = W

local counter = 0
function W.Name(prefix)
    counter = counter + 1
    return "Groupbound_" .. (prefix or "C") .. counter
end

function W.Label(parent, font, color, text, align)
    local l = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    l:SetFont(font or "ZoFontGame")
    l:SetColor(G.RGBA(color or C.normal))
    l:SetText(text or "")
    if align then l:SetHorizontalAlignment(align) end
    l:SetMouseEnabled(false)
    return l
end

function W.Tex(parent, texture, w, h, color, alpha)
    local t = WINDOW_MANAGER:CreateControl(nil, parent, CT_TEXTURE)
    if texture then t:SetTexture(texture) end
    if w then t:SetDimensions(w, h or w) end
    if color then t:SetColor(G.RGBA(color, alpha)) end
    t:SetMouseEnabled(false)
    return t
end

function W.Virtual(parent, template, prefix)
    return WINDOW_MANAGER:CreateControlFromVirtual(W.Name(prefix or "V"), parent, template)
end

-- the game's large button; onClick(button)
function W.Button(parent, text, onClick, width, tooltip)
    local b = W.Virtual(parent, "ZO_DefaultButton", "Btn")
    b:SetText(text or "")
    if width then b:SetWidth(width) end
    b:SetHandler("OnClicked", function(self) onClick(self) end)
    if tooltip then
        b:SetHandler("OnMouseEnter", function(self)
            local t = type(tooltip) == "function" and tooltip() or tooltip
            if t and t ~= "" then
                InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -4, TOP)
                SetTooltipText(InformationTooltip, t)
            end
        end)
        b:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
    end
    return b
end

-- the game's checkbox with its label; get() / set(checked)
function W.Check(parent, text, get, set, tooltip)
    local c = W.Virtual(parent, "ZO_CheckButton", "Check")
    ZO_CheckButton_SetLabelText(c, text)
    ZO_CheckButton_SetToggleFunction(c, function(_, checked) set(checked) end)
    ZO_CheckButton_SetCheckState(c, get() and true or false)
    if tooltip then
        local label = c:GetNamedChild("Label") or c
        local function Enter()
            InitializeTooltip(InformationTooltip, c, RIGHT, -8, 0, LEFT)
            SetTooltipText(InformationTooltip, tooltip)
        end
        c:SetHandler("OnMouseEnter", Enter, "Groupbound")
        c:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end, "Groupbound")
        if label ~= c then
            label:SetMouseEnabled(true)
            label:SetHandler("OnMouseEnter", Enter, "Groupbound")
            label:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end, "Groupbound")
        end
    end
    function c:Refresh() ZO_CheckButton_SetCheckState(self, get() and true or false) end
    return c
end

-- a text field: dark box with a thin frame (the frame lightens while you type), the game's own
-- edit box inside (ZO_DefaultEdit / ZO_DefaultEditMultiLine: click to type, Enter / Escape to
-- stop). (The game's backdrop template ZO_SingleLineEditBackdrop_Keyboard drew as a squashed pale
-- bar with a line through it when made from Lua, and its edit box was too thin to click.)
local function Field(parent, width, height, hint, template)
    local box = WINDOW_MANAGER:CreateControl(nil, parent, CT_CONTROL)
    box:SetDimensions(width, height)
    box:SetMouseEnabled(true)
    local fill = W.Tex(box, nil, nil, nil, C.panel, 0.55)
    fill:SetAnchorFill(box)
    local lines = {}
    local function Line(a1, a2, horizontal)
        local t = W.Tex(box, nil, nil, nil, C.dim, 0.6)
        t:SetAnchor(a1, box, a1, 0, 0)
        t:SetAnchor(a2, box, a2, 0, 0)
        if horizontal then t:SetHeight(1) else t:SetWidth(1) end
        lines[#lines + 1] = t
    end
    Line(TOPLEFT, TOPRIGHT, true)
    Line(BOTTOMLEFT, BOTTOMRIGHT, true)
    Line(TOPLEFT, BOTTOMLEFT, false)
    Line(TOPRIGHT, BOTTOMRIGHT, false)
    local edit = W.Virtual(box, template, "Edit")
    edit:ClearAnchors()
    edit:SetAnchor(TOPLEFT, box, TOPLEFT, 8, template == "ZO_DefaultEdit" and 3 or 5)
    edit:SetAnchor(BOTTOMRIGHT, box, BOTTOMRIGHT, -8, template == "ZO_DefaultEdit" and -1 or -5)
    if hint and edit.SetDefaultText then edit:SetDefaultText(hint) end
    local function Frame(c, a)
        for _, t in ipairs(lines) do t:SetColor(G.RGBA(c, a)) end
    end
    edit:SetHandler("OnFocusGained", function() Frame(C.normal, 1) end, "GroupboundFrame")
    edit:SetHandler("OnFocusLost", function() Frame(C.dim, 0.6) end, "GroupboundFrame")
    box:SetHandler("OnMouseUp", function() edit:TakeFocus() end)
    box.edit = edit
    return box, edit
end

-- single line (30 high, like the game's search fields)
function W.Edit(parent, width, hint)
    return Field(parent, width, 30, hint, "ZO_DefaultEdit")
end

-- several lines
function W.MultiEdit(parent, width, height, hint)
    return Field(parent, width, height, hint, "ZO_DefaultEditMultiLine")
end

-- the game's stretchable divider
function W.Divider(parent)
    return W.Virtual(parent, "ZO_DynamicHorizontalDivider", "Divider")
end

-- row highlight: a light white wash (starts hidden). Show / hide it with W.HighlightTo, which fades
-- to its own strength. (On a plain texture SetAlpha REPLACES the color's alpha, it doesn't
-- multiply: fading to 1 drew a SOLID white bar over the text. Same lesson as Set Hunter's scope
-- picker. A gradient (SetGradientColors) ignores its alpha too. The game's ZO_ListEntryHighlight is
-- three stretched pieces made for taller rows: cyan with a seam at our row height.)
-- Look (picked 2026-10-14, sketch C "soft light", no gold): Textures/rowlight.dds = a soft white
-- light behind the left part of the row, fading out on all sides (made by
-- _GroupboundDev/make_logo.ps1). A NEW file only exists after a full restart, so until the game
-- has it (probe below) the highlight is the plain wash.
local ROW_LIGHT = "Groupbound/Textures/rowlight.dds"
local highlights = setmetatable({}, { __mode = "k" })
local lightReady = false

local function UseLight(t)
    t:SetTexture(ROW_LIGHT)
    t:SetColor(1, 1, 1, 1)
end

function W.Highlight(parent, strength, light)
    local t = W.Tex(parent)
    t:SetAnchorFill(parent)
    t:SetColor(1, 1, 1, 1)
    strength = strength or 0.16
    -- plain wash (before the texture is there) / the light (hover 0.12, picked 0.22; `light` overrides).
    -- Was strength * 2.5 (hover 0.3, picked 0.55): far too bright, user 2026-10-14.
    t.plainStrength = strength * 0.6
    t.lightStrength = light or math.min(0.9, strength)
    t:SetDrawLevel(1)
    t:SetAlpha(0)
    -- hidden while off: inside a scroll list the game's edge fade overrides alpha 0, and the
    -- "invisible" highlights drew as white bars (achievement picker, 2026-10-14)
    t:SetHidden(true)
    highlights[t] = true
    if lightReady then UseLight(t) end
    return t
end

-- fades a W.Highlight in (on) or out
function W.HighlightTo(t, key, on, ms)
    local s = lightReady and t.lightStrength or t.plainStrength
    if on then
        t:SetHidden(false)
        W.FadeTo(t, key, s, ms)
    else
        W.FadeTo(t, key, 0, ms, function() t:SetHidden(true) end)
    end
end

-- the light's file loaded? (an invisible copy on its own window; checked every second for 10 s)
function W.InitRowLight()
    local probeWin = WINDOW_MANAGER:CreateTopLevelWindow("Groupbound_LightProbe")
    probeWin:SetDimensions(1, 1)
    probeWin:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 0, 0)
    local probe = W.Tex(probeWin, ROW_LIGHT, 1, 1)
    probe:SetAnchor(TOPLEFT, probeWin, TOPLEFT, 0, 0)
    probe:SetAlpha(0)
    local tries = 0
    local function Check()
        tries = tries + 1
        local loaded = probe.IsTextureLoaded and probe:IsTextureLoaded()
        if loaded and probe.GetTextureFileDimensions then
            loaded = probe:GetTextureFileDimensions() == 256
        end
        if loaded then
            lightReady = true
            for t in pairs(highlights) do UseLight(t) end
        elseif tries < 10 then
            G.Later(Check, 1000, "Widgets")
        end
    end
    G.Later(Check, 500, "Widgets")
end

function W.Backdrop(parent)
    local b = W.Virtual(parent, "ZO_DefaultBackdrop", "Bd")
    b:SetAnchorFill(parent)
    return b
end

-- a scroll area that clips (the game's ZO_ScrollContainer); returns the scroll and its child
function W.Scroll(parent, name)
    local s = WINDOW_MANAGER:CreateControlFromVirtual(name or W.Name("Scroll"), parent, "ZO_ScrollContainer")
    return s, s:GetNamedChild("ScrollChild")
end

-- tooltip on any control (text or function returning text)
-- (a text field from W.Edit / W.MultiEdit: its edit box covers the frame and takes the mouse, so the
-- tooltip goes on the edit box too, shown above the whole field; named handlers keep the game's own)
function W.Tip(control, text)
    local function Enter()
        local t = type(text) == "function" and text() or text
        if t and t ~= "" then
            InitializeTooltip(InformationTooltip, control, BOTTOM, 0, -4, TOP)
            SetTooltipText(InformationTooltip, t)
        end
    end
    local function Exit() ClearTooltip(InformationTooltip) end
    control:SetMouseEnabled(true)
    control:SetHandler("OnMouseEnter", Enter)
    control:SetHandler("OnMouseExit", Exit)
    if control.edit then
        control.edit:SetHandler("OnMouseEnter", Enter, "GroupboundTip")
        control.edit:SetHandler("OnMouseExit", Exit, "GroupboundTip")
    end
end

-- a clickable text line in the game's colors: normal, highlight on hover, selected (white).
-- onClick(label, button)
function W.TextButton(parent, font, text, onClick)
    local l = W.Label(parent, font, C.normal, text)
    l:SetMouseEnabled(true)
    l.hover = false
    function l:Paint()
        local c = self.selected and C.selected or (self.hover and C.highlight or (self.disabled and C.disabled or C.normal))
        self:SetColor(G.RGBA(c))
    end
    l:SetHandler("OnMouseEnter", function(self)
        self.hover = true
        self:Paint()
        if self.tooltip then
            InitializeTooltip(InformationTooltip, self, RIGHT, -8, 0, LEFT)
            SetTooltipText(InformationTooltip, type(self.tooltip) == "function" and self.tooltip() or self.tooltip)
        end
    end)
    l:SetHandler("OnMouseExit", function(self)
        self.hover = false
        self:Paint()
        ClearTooltip(InformationTooltip)
    end)
    l:SetHandler("OnMouseUp", function(self, button, upInside)
        if upInside then onClick(self, button) end
    end)
    function l:SetSelected(on)
        self.selected = on and true or false
        self:Paint()
    end
    return l
end

-- fades a control's alpha to target (Anim engine; instant with animations off)
function W.FadeTo(control, key, target, ms, done)
    local from = control:GetAlpha()
    -- already there (and not on the way elsewhere): nothing to animate
    if math.abs(from - target) < 0.01 and not Anim.IsRunning(key) then
        control:SetAlpha(target)
        if done then done() end
        return
    end
    Anim.Run(key, ms or Anim.STD, Anim.Out, function(p) control:SetAlpha(Anim.Lerp(from, target, p)) end, done)
end
