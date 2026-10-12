local Chronos = _G['Chronos']

function Chronos:ConvRGBToHex(r, g, b)
    return string.format("%.2x%.2x%.2x", zo_floor(r * 255), zo_floor(g * 255), zo_floor(b * 255))
end

function Chronos:ConvHexToRGB(colorString)
    local r = tonumber(string.sub(colorString, 1, 2), 16) or 255
    local g = tonumber(string.sub(colorString, 3, 4), 16) or 255
    local b = tonumber(string.sub(colorString, 5, 6), 16) or 255
    return r / 255, g / 255, b / 255
end

function Chronos:GetDefaultColor(key)
    local r, g, b = self:ConvHexToRGB(self.defaults[key])
    return { r = r, g = g, b = b }
end