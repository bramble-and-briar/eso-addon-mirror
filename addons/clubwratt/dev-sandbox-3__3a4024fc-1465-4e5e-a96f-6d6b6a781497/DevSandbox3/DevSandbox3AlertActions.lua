-- DevSandbox3AlertActions.lua: Big persistent on-screen text when a node is detected (PvP UA style)

local AlertActions = {}

local AlertUtils = DevSandbox3.AlertUtils
local LogUtils = DevSandbox3.LogUtils

local UPDATE_NAME = DevSandbox3.name .. "_AlertExpiry"

AlertActions.window = nil
AlertActions.label = nil

local function GetSettings()
    return DevSandbox3.state.savedVars.settings
end

local function ApplyStyle()
    local label = AlertActions.label
    if not label then return end
    local alert = DevSandbox3.state.savedVars.activeAlert
    label:SetFont(AlertUtils.BuildFont(GetSettings().alertFontSize))
    local color = (alert and alert.candidate) and AlertUtils.CANDIDATE_COLOR or AlertUtils.CONFIRMED_COLOR
    label:SetColor(unpack(color))
end

---Sync the control with savedVars.activeAlert.
function AlertActions.Refresh()
    local window, label = AlertActions.window, AlertActions.label
    if not window or not label then return end
    local alert = DevSandbox3.state.savedVars.activeAlert
    local visible = alert ~= nil and GetSettings().alertEnabled
    if visible then
        label:SetText(alert.text)
        ApplyStyle()
    end
    window:SetHidden(not visible)
end

local function CheckExpiry()
    local savedVars = DevSandbox3.state.savedVars
    if AlertUtils.IsExpired(savedVars.activeAlert, savedVars.settings.alertAutoDismissSeconds, GetTimeStamp()) then
        AlertActions.Dismiss()
    end
end

---@param name string
---@param distanceText string|nil
---@param candidate boolean
function AlertActions.Show(name, distanceText, candidate)
    local savedVars = DevSandbox3.state.savedVars
    if candidate and not savedVars.settings.alertOnCandidates then
        return
    end
    savedVars.activeAlert = {
        text = AlertUtils.BuildText(name, distanceText, candidate),
        candidate = candidate,
        at = GetTimeStamp(),
    }
    if savedVars.settings.alertEnabled and savedVars.settings.alertSound then
        PlaySound(SOUNDS.ACHIEVEMENT_AWARDED)
    end
    AlertActions.Refresh()
end

function AlertActions.Dismiss()
    local savedVars = DevSandbox3.state.savedVars
    if savedVars.activeAlert then
        savedVars.activeAlert = nil
        LogUtils.Log("Alert dismissed")
    end
    AlertActions.Refresh()
end

---Preview the alert without recording anything (settings menu button).
function AlertActions.Test()
    AlertActions.Show("Lost Imperial Notes (test)", "42m", false)
end

function AlertActions.Initialize()
    local window = WINDOW_MANAGER:CreateTopLevelWindow(DevSandbox3.name .. "_AlertWindow")
    window:SetDrawLayer(DL_OVERLAY)
    window:SetDrawTier(DT_HIGH)
    window:SetAnchor(TOP, GuiRoot, TOP, 0, 160)
    window:SetDimensions(1400, 200)
    window:SetMouseEnabled(false)
    window:SetHidden(true)

    local label = WINDOW_MANAGER:CreateControl(DevSandbox3.name .. "_AlertLabel", window, CT_LABEL)
    label:SetAnchorFill(window)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

    AlertActions.window = window
    AlertActions.label = label

    -- Only draw over the HUD, not inside menus / the map.
    local fragment = ZO_HUDFadeSceneFragment:New(window)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)

    EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, 1000, CheckExpiry)
    AlertActions.Refresh()
end

DevSandbox3.AlertActions = AlertActions
