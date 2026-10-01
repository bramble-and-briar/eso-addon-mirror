local O = OneCrosshair
O.LowResource = {}
function O.LowResource.Active(enabled, fraction) return enabled and fraction <= .25 end
