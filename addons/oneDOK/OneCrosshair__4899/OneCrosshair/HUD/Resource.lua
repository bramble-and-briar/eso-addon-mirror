local O = OneCrosshair
O.Resource = {}
function O.Resource.New(powerType, color)
    return { powerType = powerType, color = color, fraction = 1, maximum = 0 }
end
function O.Resource.Read(self, now)
    local current, maximum = GetUnitPower("player", self.powerType)
    self.maximum = maximum
    self.fraction = maximum > 0 and O.Clamp(current / maximum) or 1
    if not self.animation then self.animation = O.Animator.New(self.fraction) end
    O.Animator.To(self.animation, self.fraction, now, 150)
    return O.Animator.Value(self.animation, now)
end
