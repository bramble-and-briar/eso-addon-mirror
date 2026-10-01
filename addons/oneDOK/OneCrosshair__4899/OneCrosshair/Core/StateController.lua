local O = OneCrosshair
O.StateController = {}
function O.StateController.Read()
    local target = DoesUnitExist("reticleover")
    if not target then
        local exists = GetGameCameraInteractableInfo()
        target = exists == true
    end
    return {
        geometry = IsBlockActive() and "block" or (target and "target" or "normal"),
        combat = IsUnitInCombat("player"),
        -- No verified general pursuit signal in public API 101051.
        pursuit = false,
    }
end
