-- CameraAnglesState.lua: Pure data initialization

local CameraAnglesState = {}

function CameraAnglesState.Create()
    ---@type CameraAnglesState
    return {
        probe = nil,
    }
end

CameraAngles.State = CameraAnglesState
