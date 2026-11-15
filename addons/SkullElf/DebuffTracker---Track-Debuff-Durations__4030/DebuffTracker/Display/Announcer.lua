-- Screen alerts fired by condition rules ("Screen alert (once)"): a large icon + text near the top
-- of the screen that pops in, holds, and fades. Up to three stack vertically.

local DT = DebuffTracker
local A = DT.Announcer
local U = DT.Util
local WM = WINDOW_MANAGER

local MAX_LINES = 3
local HOLD = 2.2
local FADE = 0.5

local root
local lines = {}

local function Create()
    root = WM:CreateTopLevelWindow("DebuffTracker5_Announcer")
    root:SetDimensions(800, 3 * 54)
    root:SetMouseEnabled(false)
    root:SetHidden(true)
    local fragment = ZO_HUDFadeSceneFragment:New(root)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
    A.fragment = fragment
    for i = 1, MAX_LINES do
        local line = WM:CreateControl(nil, root, CT_CONTROL)
        line:SetDimensions(800, 50)
        local icon = WM:CreateControl(nil, line, CT_TEXTURE)
        icon:SetDimensions(42, 42)
        local label = WM:CreateControl(nil, line, CT_LABEL)
        label:SetFont("$(BOLD_FONT)|30|thick-outline")
        label:SetColor(1, 0.88, 0.5, 1)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        label:SetAnchor(CENTER, line, CENTER, 24, 0)
        icon:SetAnchor(RIGHT, label, LEFT, -10, 0)
        line:SetHidden(true)
        lines[i] = { control = line, icon = icon, label = label, shownAt = 0 }
    end
    root:SetHandler("OnUpdate", function() A.Animate() end)
end

function A.ApplyPosition()
    if not root then Create() end
    local s = DT.Profiles.Settings()
    root:ClearAnchors()
    root:SetAnchor(TOP, GuiRoot, TOP, 0, s.alertY or 160)
    local size = s.alertFontSize or 30
    for _, l in ipairs(lines) do l.label:SetFont(string.format("$(BOLD_FONT)|%d|thick-outline", size)) end
end

function A.Show(text, icon)
    if not root then Create(); A.ApplyPosition() end
    if not text or text == "" then return end
    -- Same text already showing: refresh it instead of stacking duplicates.
    local slot
    for _, l in ipairs(lines) do
        if not l.control:IsHidden() and l.text == text then slot = l; break end
    end
    if not slot then
        -- Shift down: newest on top.
        for i = MAX_LINES, 2, -1 do
            local a, b = lines[i], lines[i - 1]
            a.text, a.iconPath, a.shownAt = b.text, b.iconPath, b.shownAt
            a.label:SetText(b.text or ""); a.icon:SetTexture(b.iconPath or DT.Const.DEFAULT_ICON)
            a.control:SetHidden(b.control:IsHidden())
        end
        slot = lines[1]
    end
    slot.text, slot.iconPath, slot.shownAt = text, icon, U.Now()
    slot.label:SetText(text)
    slot.icon:SetTexture(icon or DT.Const.DEFAULT_ICON)
    slot.icon:SetHidden(icon == nil)
    slot.control:SetHidden(false)
    for i, l in ipairs(lines) do
        l.control:ClearAnchors()
        l.control:SetAnchor(TOP, root, TOP, 0, (i - 1) * 54)
    end
    A.fragment:SetHiddenForReason("idle", false)
end

function A.Animate()
    local now = U.Now()
    local any = false
    for _, l in ipairs(lines) do
        if not l.control:IsHidden() then
            local age = now - l.shownAt
            if age > HOLD + FADE then
                l.control:SetHidden(true)
                l.text = nil
            else
                any = true
                local alpha = age > HOLD and (1 - (age - HOLD) / FADE) or 1
                local scale = age < 0.12 and (1.3 - age / 0.12 * 0.3) or 1
                l.control:SetAlpha(alpha)
                l.control:SetScale(scale)
            end
        end
    end
    if not any then A.fragment:SetHiddenForReason("idle", true) end
end

function A.Initialize()
    if not root then Create() end
    A.ApplyPosition()
    A.fragment:SetHiddenForReason("idle", true)
end
