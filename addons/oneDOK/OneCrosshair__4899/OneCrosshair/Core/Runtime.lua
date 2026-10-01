local O = OneCrosshair
O.Runtime = {}
function O.Runtime.New(settings)
    local self = { settings = settings, active = false, visibility = O.VisibilityController.New(),
        health = O.Health.New(), magicka = O.Magicka.New(), stamina = O.Stamina.New(),
        shield = O.Shield.New(), gcd = O.GCD.New() }
    self.root = WINDOW_MANAGER:CreateTopLevelWindow("OneCrosshairHUD")
    self.root:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    self.root:SetDimensions(80, 70)
    self.root:SetMouseEnabled(false)
    self.root:SetHidden(true)
    self.crosshair = O.CrosshairController.New(self.root)
    self.crosshair.root:SetAnchor(CENTER, self.root, CENTER, 0, 0)
    self.ring = O.ResourceRing.New(self.root)
    O.ReticleReplacement.Initialize()
    O.NativeReticleColor.Initialize()
    O.CombatFeedback.Initialize(settings, self.crosshair)
    O.AbilityTimings.Initialize()
    O.HeavyChannel.Initialize(settings)
    EVENT_MANAGER:RegisterForEvent(O.name .. "Activated", EVENT_PLAYER_ACTIVATED, function()
        self.active = true
        self.visibility = O.VisibilityController.New()
    end)
    EVENT_MANAGER:RegisterForEvent(O.name .. "Deactivated", EVENT_PLAYER_DEACTIVATED, function()
        self.active = false
        self.gcd = O.GCD.New()
        self.root:SetHidden(true)
        O.ReticleReplacement.SetActive(false)
        O.NativeReticleColor.Update(false)
    end)
    -- RegisterForUpdate keeps running while our top-level window is hidden.
    EVENT_MANAGER:RegisterForUpdate(O.name, 16, function() O.Runtime.Update(self) end)
    return self
end
function O.Runtime.Update(self)
    local s, now = self.settings, GetFrameTimeMilliseconds()
    local visible = self.active and IsGameCameraActive() and not IsGameCameraUIModeActive()
        and not IsReticleHidden() and not IsUnitDead("player")
        and (not RETICLE or not RETICLE.control:IsHidden())
    self.root:SetHidden(not visible)
    local native = O.PresetRegistry.Get(s.preset).native == true
    O.ReticleReplacement.SetActive(visible and not native)
    self.crosshair.root:SetHidden(native)
    O.NativeReticleColor.Update(visible and native, native and IsUnitInCombat("player"), now)
    if not visible then
        O.HeavyChannel.Read(s.gcd, now, false) -- expire without a hidden completion frame
        self.gcd = O.GCD.New()
        return
    end
    O.ResourceRing.Configure(self.ring, s)
    local state = O.StateController.Read()
    O.CrosshairController.SetPreset(self.crosshair, s.preset, state.geometry)
    O.CrosshairController.Update(self.crosshair, state, s.crosshairOpacity, now)
    local fills = { health = O.Resource.Read(self.health, now), magicka = O.Resource.Read(self.magicka, now),
        stamina = O.Resource.Read(self.stamina, now) }
    local healthAlpha
    for _, name in ipairs({ "health", "magicka", "stamina" }) do
        local resource = self[name]
        local alpha = O.VisibilityController.Alpha(self.visibility, name, s.visibility, s.resources,
            state.combat, resource.fraction < 1, now) * s.hudOpacity
        if name == "health" then healthAlpha = alpha end
        local glow = O.LowResource.Active(s.lowResource, resource.fraction)
        O.ResourceRing.Draw(self.ring, name, fills[name], resource.color, alpha, glow)
    end
    O.ResourceRing.Draw(self.ring, "shield", O.Shield.Read(self.shield, self.health.maximum, now),
        O.Shield.color, s.shield and healthAlpha or 0, false)
    local heavy, ready = O.HeavyChannel.Read(s.gcd, now)
    local gcd = O.GCD.Read(self.gcd)
    local active = heavy ~= nil or (s.gcd and gcd.active)
    local alpha = O.VisibilityController.Alpha(self.visibility, "bottom", s.visibility,
        s.gcd or heavy ~= nil, state.combat, active, now) * s.hudOpacity
    local fill, color, intensity = O.GCD.Presentation(gcd)
    if heavy ~= nil then fill, color, intensity = O.HeavyChannel.Presentation(heavy, ready) end
    O.ResourceRing.Draw(self.ring, "bottom", fill, color, alpha * intensity, false)
end
