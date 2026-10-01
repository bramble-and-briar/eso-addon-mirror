OneCrosshair = { name = "OneCrosshair", version = "1.0", author = "oneDOK" }
local O = OneCrosshair
function O.Clamp(value) return math.max(0, math.min(1, value or 0)) end
function O.Control(parent, kind)
    return WINDOW_MANAGER:CreateControl(nil, parent, kind or CT_CONTROL)
end
function O.Dot(parent, size)
    local c = O.Control(parent, CT_TEXTURE)
    c:SetTexture("OneCrosshair/Assets/Disc.dds")
    c:SetDimensions(size, size)
    return c
end
