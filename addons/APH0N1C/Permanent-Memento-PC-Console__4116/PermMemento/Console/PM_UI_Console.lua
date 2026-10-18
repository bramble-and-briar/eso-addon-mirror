--[[
    Copyright © 2025-2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

PermMementoCore = PermMementoCore or {}
local PM = PermMementoCore
function PM.create_gamepad_mover(target)
	return LibAPH.CreateGamepadMover(target)
end
