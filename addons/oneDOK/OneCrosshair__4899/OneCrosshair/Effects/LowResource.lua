local O = OneCrosshair
O.LowResource = {}
function O.LowResource.Active(enabled, fraction) return enabled and fraction <= .25 end
function O.LowResource.New() return O.Animator.New(0) end
function O.LowResource.Intensity(animation, active, now)
    -- Only appearance animates; recovery/disable still removes the warning now.
    O.Animator.To(animation, active and 1 or 0, now, active and 180 or 0)
    return O.Animator.Value(animation, now)
end
function O.LowResource.Reset(animations, now)
    for _, animation in pairs(animations) do O.LowResource.Intensity(animation, false, now) end
end
