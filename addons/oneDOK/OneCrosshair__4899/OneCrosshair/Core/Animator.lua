local O = OneCrosshair
O.Animator = {}
function O.Animator.New(value)
    return { from = value, value = value, target = value, start = 0, duration = 0 }
end
function O.Animator.Value(a, now)
    local t = a.duration > 0 and O.Clamp((now - a.start) / a.duration) or 1
    t = t * t * (3 - 2 * t)
    a.value = a.from + (a.target - a.from) * t
    return a.value
end
function O.Animator.To(a, target, now, duration)
    if a.target == target then return end
    a.from = O.Animator.Value(a, now)
    a.target, a.start, a.duration = target, now, duration
end
