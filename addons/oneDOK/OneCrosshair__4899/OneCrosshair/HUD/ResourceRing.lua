local O = OneCrosshair
O.ResourceRing = {}
local R = O.ResourceRing
local names = { "health", "magicka", "stamina", "bottom", "shield" }
function R.New(parent)
    local self = { root = O.Control(parent), textureArcs = {} }
    self.root:SetAnchor(CENTER, parent, CENTER, 0, 0)
    for _, name in ipairs(names) do self.textureArcs[name] = O.ArcRenderer.New(self.root, name) end
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
    local assets = O.ArcAssets
    self.textured = radius == assets.radius and thickness == assets.thickness and length == assets.length
    for _, arc in pairs(self.textureArcs) do
        O.ArcRenderer.Hidden(arc, not self.textured)
        arc.fill, arc.color, arc.alpha, arc.glowing = nil, nil, nil, nil
    end
    if self.textured then
        self.arcs = self.textureArcs
        if self.fallback then self.fallback.root:SetHidden(true) end
    else
        -- Preserve arbitrary code-configured geometry. Regenerate assets to
        -- get curved textures for new dimensions; no settings change.
        self.fallback = self.fallback or O.SegmentedArcRenderer.New(self.root)
        O.SegmentedArcRenderer.Configure(self.fallback, settings)
        self.fallback.root:SetHidden(length <= 0)
        self.arcs = self.fallback.arcs
    end
end
function R.Draw(self, name, fill, color, alpha, glowing)
    -- Boolean static previews and animated runtime intensity share the renderer.
    glowing = type(glowing) == "number" and O.Clamp(glowing) or (glowing and 1 or 0)
    if self.textured then O.ArcRenderer.Draw(self.arcs[name], name, fill, color, alpha, glowing)
    else O.SegmentedArcRenderer.Draw(self.fallback, name, fill, color, alpha, glowing) end
end
