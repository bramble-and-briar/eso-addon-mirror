local O = OneCrosshair
O.VisibilityController = {}
function O.VisibilityController.New()
    return { items = {}, mode = nil }
end
function O.VisibilityController.Alpha(self, key, mode, enabled, combat, active, now)
    if self.mode ~= mode then self.items, self.mode = {}, mode end
    local item = self.items[key]
    if not item then
        item = { last = nil, alpha = O.Animator.New(0) }
        self.items[key] = item
    end
    if not enabled or mode == "OFF" then
        item.last, item.alpha = nil, O.Animator.New(0)
        return 0
    end
    local show = mode == "ALWAYS" or (mode == "COMBAT_ONLY" and combat)
        or (mode == "DYNAMIC" and active)
    if show then item.last = now end
    local keep = show or (item.last ~= nil and now - item.last < 2000)
    O.Animator.To(item.alpha, keep and 1 or 0, now, keep and 100 or 200)
    return O.Animator.Value(item.alpha, now)
end
