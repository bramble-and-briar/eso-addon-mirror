local O = OneCrosshair
O.ResourceRing = {}
local R = O.ResourceRing
local samples, glowBands = 64, 8
local specs = {
    health = { angle = -math.pi / 2, centered = true, direction = 1 },
    shield = { angle = -math.pi / 2, centered = true, direction = 1 },
    bottom = { angle = math.pi / 2, centered = true, direction = -1 },
    magicka = { angle = math.pi, direction = 1 },
    stamina = { angle = 0, direction = -1 },
}
local function Line(parent, level)
    local control = O.Control(parent, CT_LINE)
    control:SetDrawLevel(level)
    control:SetPixelRoundingEnabled(false)
    control:SetColor(1, 1, 1, 0)
    return control
end
local function Position(line, parent, radius, a, b, thickness)
    line:ClearAnchors()
    line:SetAnchor(TOPLEFT, parent, CENTER, radius * math.cos(a), radius * math.sin(a))
    line:SetAnchor(BOTTOMRIGHT, parent, CENTER, radius * math.cos(b), radius * math.sin(b))
    line:SetThickness(thickness)
end
function R.New(parent)
    local self = { root = O.Control(parent), arcs = {} }
    self.root:SetAnchor(CENTER, parent, CENTER, 0, 0)
    for _, name in ipairs({ "health", "magicka", "stamina", "bottom", "shield" }) do
        local arc = {}
        for i = 1, samples do
            local t = (i - .5) / samples
            local point = { control = Line(self.root, name == "shield" and 4 or 2), glows = {},
                threshold = specs[name].centered and math.abs(2 * t - 1) or t }
            if name == "health" or name == "magicka" or name == "stamina" then
                for band = 1, glowBands do point.glows[band] = Line(self.root, 0) end
            end
            arc[i] = point
        end
        self.arcs[name] = arc
    end
    R.Configure(self, {})
    return self
end
function R.Configure(self, settings)
    local radius, thickness, length = settings.resourceRadius or O.Config.resourceRadius,
        settings.resourceThickness or O.Config.resourceThickness, settings.resourceLength or O.Config.resourceLength
    if self.radius == radius and self.thickness == thickness and self.length == length then return end
    self.radius, self.thickness, self.length = radius, thickness, length
    self.root:SetDimensions(2 * (radius + 2.5 * thickness), 2 * (radius + 2.5 * thickness))
    self.root:SetHidden(length <= 0)
    local span = math.pi / 2 * length / 100
    for name, arc in pairs(self.arcs) do
        local spec = specs[name]
        for i, point in ipairs(arc) do
            local a = spec.angle + spec.direction * span * ((i - 1) / samples - .5)
            local b = spec.angle + spec.direction * span * (i / samples - .5)
            Position(point.control, self.root, radius, a, b, thickness + (name == "shield" and 2 or 0))
            -- Fading radial bands span the WHOLE attribute, even the empty part.
            -- Their support lies outside the solid edge, R+t/2 through R+2.5t.
            for band, glow in ipairs(point.glows) do
                local width = 2 * thickness / glowBands
                local r = radius + thickness / 2 + (band - .5) * width
                Position(glow, self.root, r, a, b, width)
            end
        end
    end
end
function R.Draw(self, name, fill, color, alpha, glowing)
    local arc = self.arcs[name]
    if arc.fill == fill and arc.color == color and arc.alpha == alpha and arc.glowing == glowing then return end
    local glowChanged = arc.color ~= color or arc.alpha ~= alpha or arc.glowing ~= glowing
    arc.fill, arc.color, arc.alpha, arc.glowing = fill, color, alpha, glowing
    for _, point in ipairs(arc) do
        local coverage = O.Clamp((fill - point.threshold) * samples + .5)
        point.control:SetColor(color[1], color[2], color[3], coverage * alpha)
        if glowChanged then
            for band, glow in ipairs(point.glows) do
                local strength = (1 - (band - .5) / glowBands) ^ 2
                glow:SetColor(color[1], color[2], color[3], glowing and alpha * .6 * strength or 0)
            end
        end
    end
end
