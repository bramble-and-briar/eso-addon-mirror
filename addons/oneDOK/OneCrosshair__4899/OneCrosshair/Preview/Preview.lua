local O = OneCrosshair
O.Preview = {}
function O.Preview.Initialize(panel, settings)
    local self = O.Preview
    self.settings, self.examples = settings, {}
    self.root = O.Control(panel)
    self.root:SetAnchor(TOPLEFT, panel, TOPLEFT, 0, 0)
    self.root:SetDimensions(480, 195)
    for i, state in ipairs({ "normal", "target", "block" }) do
        local holder = O.Control(self.root)
        holder:SetDimensions(1, 1)
        holder:SetAnchor(TOPLEFT, self.root, TOPLEFT, 80 + (i - 1) * 160, 85)
        local crosshair = O.CrosshairController.New(holder)
        crosshair.root:SetAnchor(CENTER, holder, CENTER, 0, 0)
        local ring = O.ResourceRing.New(holder)
        local label = O.Control(self.root, CT_LABEL)
        label:SetFont("ZoFontGameSmall")
        label:SetAnchor(TOP, holder, CENTER, 0, 80)
        label:SetText(GetString(_G["SI_ONECROSSHAIR_" .. string.upper(state)]))
        self.examples[i] = { crosshair = crosshair, ring = ring, state = state }
    end
    self.root:SetHidden(not self.open)
    O.Preview.Refresh()
end
function O.Preview.Refresh()
    local self = O.Preview
    if not self.root then return end
    local s = self.settings
    for _, example in ipairs(self.examples) do
        O.CrosshairController.SetPreset(example.crosshair, s.preset, example.state)
        O.CrosshairController.Update(example.crosshair, { geometry = example.state },
            example.crosshair.preset.native and 1 or s.crosshairOpacity, GetFrameTimeMilliseconds(), true)
        local ring = example.ring
        O.ResourceRing.Configure(ring, s)
        -- Large experimental dimensions fit the preview cell without changing
        -- gameplay geometry or crosshair size. Samples never read live resources.
        ring.root:SetScale(math.min(1, 145 / (2 * (ring.radius + 2.5 * ring.thickness))))
        local alpha = s.visibility ~= "OFF" and s.hudOpacity or 0
        for _, item in ipairs({ {"health", .2, O.Health}, {"magicka", .65, O.Magicka}, {"stamina", .8, O.Stamina} }) do
            O.ResourceRing.Draw(ring, item[1], item[2], item[3].New().color,
                s.resources and alpha or 0, O.LowResource.Active(s.lowResource, item[2]))
        end
        O.ResourceRing.Draw(ring, "shield", .1, O.Shield.color, s.resources and s.shield and alpha or 0, false)
        O.ResourceRing.Draw(ring, "bottom", .6, O.GCD.idleColor, s.gcd and alpha or 0, false)
    end
end
function O.Preview.Show(show)
    O.Preview.open = show
    if not O.Preview.root then return end
    O.Preview.root:SetHidden(not show)
    if show then O.Preview.Refresh() end
end
