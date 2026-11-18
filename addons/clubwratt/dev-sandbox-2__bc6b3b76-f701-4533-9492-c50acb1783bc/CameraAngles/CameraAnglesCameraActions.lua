-- CameraAnglesCameraActions.lua: Reads the camera's orientation and prints it to chat
--
-- The camera has no orientation getter of its own. Set3DRenderSpaceToCurrentCamera
-- snaps a control's 3D render space onto the camera (the housing editor reads its
-- look direction this way), and the control then reports pitch, yaw and roll in the
-- same Euler convention the housing editor uses for a furnishing's orientation: it
-- passes HousingEditorGetFurnitureOrientation's values straight into
-- Set3DRenderSpaceOrientation for its axis indicators.

local CameraAngles = CameraAngles
local CameraUtils = CameraAngles.CameraUtils

local TOPLEVEL_NAME = "CameraAnglesTopLevel"
local PROBE_NAME = "CameraAnglesProbe"

local CameraActions = {}

---@return any probe
local function EnsureProbe()
    local state = CameraAngles.state
    if state.probe then return state.probe end
    local topLevel = WINDOW_MANAGER:CreateTopLevelWindow(TOPLEVEL_NAME)
    local probe = WINDOW_MANAGER:CreateControl(PROBE_NAME, topLevel, CT_CONTROL)
    probe:Create3DRenderSpace()
    state.probe = probe
    return probe
end

---@return CameraAnglesReading
function CameraActions.Read()
    local probe = EnsureProbe()
    Set3DRenderSpaceToCurrentCamera(PROBE_NAME)
    local pitch, yaw, roll = probe:Get3DRenderSpaceOrientation()
    local forwardX, forwardY, forwardZ = probe:Get3DRenderSpaceForward()
    ---@type CameraAnglesReading
    return {
        pitch = pitch,
        yaw = yaw,
        roll = roll,
        heading = GetPlayerCameraHeading(),
        forwardX = forwardX,
        forwardY = forwardY,
        forwardZ = forwardZ,
    }
end

---Slash command handler: one reading, printed to chat.
function CameraActions.Print()
    local lines = CameraUtils.FormatReading(CameraActions.Read())
    for _, line in ipairs(lines) do
        CHAT_ROUTER:AddSystemMessage(string.format("[%s] %s", CameraAngles.displayName, line))
    end
end

CameraAngles.CameraActions = CameraActions
