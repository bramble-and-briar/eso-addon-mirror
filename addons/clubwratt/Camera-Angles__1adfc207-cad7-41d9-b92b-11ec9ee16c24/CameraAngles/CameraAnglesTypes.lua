---@meta CameraAnglesTypes
-- CameraAnglesTypes.lua: Centralized type definitions for CameraAngles

---@class CameraAnglesState
---@field probe any|nil hidden control whose 3D render space is snapped to the camera on each read

---One reading of the camera, every angle in radians as the game returned it.
---@class CameraAnglesReading
---@field pitch number engine Euler pitch of the camera's render space
---@field yaw number engine Euler yaw of the camera's render space
---@field roll number engine Euler roll of the camera's render space
---@field heading number GetPlayerCameraHeading()
---@field forwardX number look direction, unit vector (Y is up)
---@field forwardY number
---@field forwardZ number
