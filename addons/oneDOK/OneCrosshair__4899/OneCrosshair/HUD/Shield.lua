local O = OneCrosshair
O.Shield = { color = { .72, .35, 1 } }
function O.Shield.New() return { animation = O.Animator.New(0) } end
function O.Shield.Read(self, maxHealth, now)
    local shield = 0
    if GetUnitAttributeVisualizerEffectInfo then
        shield = GetUnitAttributeVisualizerEffectInfo("player", ATTRIBUTE_VISUAL_POWER_SHIELDING,
            STAT_MITIGATION, ATTRIBUTE_HEALTH, COMBAT_MECHANIC_FLAGS_HEALTH) or 0
    end
    local fraction = maxHealth > 0 and O.Clamp(shield / maxHealth) or 0
    O.Animator.To(self.animation, fraction, now, 150)
    return O.Animator.Value(self.animation, now)
end
