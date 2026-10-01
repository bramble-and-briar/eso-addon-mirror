local O = OneCrosshair
local N = {}
O.NativeReticleColor = N
local function StopHitAnimation()
    if RETICLE and RETICLE.hitIndicatorTimeline then RETICLE.hitIndicatorTimeline:Stop() end
end
function N.Initialize()
    N.texture = RETICLE and RETICLE.reticleTexture
    if N.texture and RETICLE.OnImpactfulHit then
        -- The native hit timeline would otherwise fade combat red back to white.
        -- Only suppress that timeline while this module owns native color.
        ZO_PostHook(RETICLE, "OnImpactfulHit", function()
            if N.active then
                StopHitAnimation()
                if N.current then N.texture:SetColor(unpack(N.current)) end
            end
        end)
    end
end
function N.Update(enabled, combat, now)
    if not N.texture then return end
    if not enabled then
        if N.active then N.texture:SetColor(unpack(N.original)) end
        N.active, N.original, N.color, N.current = false, nil, nil, nil
        return
    end
    if not N.active then
        N.original = { N.texture:GetColor() }
        N.color = { O.Animator.New(N.original[1]), O.Animator.New(N.original[2]), O.Animator.New(N.original[3]) }
        N.active = true
        StopHitAnimation()
    end
    local target = combat and {1, .15, .12} or {1, 1, 1}
    for i = 1, 3 do O.Animator.To(N.color[i], target[i], now, 100) end
    N.current = { O.Animator.Value(N.color[1], now), O.Animator.Value(N.color[2], now),
        O.Animator.Value(N.color[3], now), N.original[4] }
    N.texture:SetColor(unpack(N.current))
end
