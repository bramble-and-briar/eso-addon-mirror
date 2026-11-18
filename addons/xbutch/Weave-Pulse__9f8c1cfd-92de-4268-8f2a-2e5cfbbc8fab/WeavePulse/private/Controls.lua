-- Adapted from CombatMetronome 1.7.7 / DariansUtilities 1.8.7.
-- Original authors: Darianopolis and barny. Artistic License 2.0.
-- Upstream: DariansUtilities/controls/Controls.lua. See third-party/UPSTREAM.md for modifications.

local Util = WeavePulse.Util
Util.Controls = { }
local Controls = Util.Controls

local log = Util.log

function Controls:New(t, name, parent, layer)
    local control = WINDOW_MANAGER:CreateControl(name, parent or GuiRoot, t)
    control:SetDrawLayer(DL_OVERLAY)
    control:SetDrawLevel(layer or 1)

    if (t == CT_BACKDROP) then
        Controls.InitBackdrop(control)
    elseif (t == CT_TOPLEVELCONTROL) then
        Controls.InitFrame(control)
    end

    return control
end

function Controls.InitBackdrop(backdrop)
    backdrop:SetEdgeColor(0, 0, 0, 0)
    backdrop:SetEdgeTexture(nil, 1, 1, 0, 0)
end

local function SetUnlocked(frame, state)
    frame:SetMouseEnabled(state)
    frame:SetMovable(state)
    frame.dmui.unlocked = state

    if (state or not frame.dmui.hudOnly) then
        SCENE_MANAGER:GetScene("hud"):RemoveFragment(frame.dmui.fragment)
        SCENE_MANAGER:GetScene("hudui"):RemoveFragment(frame.dmui.fragment)
        frame:SetHidden(false)
    else
        SCENE_MANAGER:GetScene("hud"):AddFragment(frame.dmui.fragment)
        SCENE_MANAGER:GetScene("hudui"):AddFragment(frame.dmui.fragment)
    end

    frame.dmui.shadow:SetHidden(not state)
    frame.dmui.label:SetHidden(not state)
    frame.dmui.label:SetFont(Util.Text.getFontString(tostring("$MEDIUM_FONT"), math.min(frame:GetHeight(), (frame:GetWidth())/5), "outline"))
end

function Controls.InitFrame(frame, label)
    local dmui = { }

    frame.dmui = dmui

    local name = frame:GetName()

    frame:SetClampedToScreen(true)

    dmui.constrain = true
    local SetDimensions = frame.SetDimensions
    frame.SetDimensions = function(self, width, height)
        if dmui.constrain then
            self:SetDimensionConstraints(width, height, width, height)
        end
        SetDimensions(self, width, height)
    end
    local SetDimensionConstraints = frame.SetDimensionConstraints
    frame.SetDimensionConstraints = function(...)
        dmui.constrain = false
        SetDimensionConstraints(...)
    end

    frame:SetResizeHandleSize(5)
    dmui.shadow = Controls:New(CT_BACKDROP, name.."Resizer", frame)
    dmui.shadow:SetAnchorFill()
    dmui.shadow:SetCenterColor(0.5, 0.5, 0.5, 0.75)
    frame.SetUnlocked = SetUnlocked
    frame.IsUnlocked = function()
        return dmui.unlocked
    end

    dmui.label = Controls:New(CT_LABEL, name.."Label", frame)
    dmui.label:SetAnchor(CENTER, frame, CENTER, 0, 0)
    dmui.label:SetText(label)

    dmui.unlocked = false
    dmui.hudOnly = true
    dmui.fragment = ZO_HUDFadeSceneFragment:New(frame)

    frame:SetUnlocked(false)

end

function Controls:NewFrame(name, label)
    local frame = WINDOW_MANAGER:CreateTopLevelWindow(name)

    Controls.InitFrame(frame, label)

    return frame
end
