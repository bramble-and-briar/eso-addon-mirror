local O = OneCrosshair
O.ReticleReplacement = {}
function O.ReticleReplacement.Initialize()
    local self = O.ReticleReplacement
    if not RETICLE or not RETICLE.reticleTexture then return end
    self.texture = RETICLE.reticleTexture
    -- Hook only the decorative texture's visibility, never RequestHidden:
    -- RequestHidden also hides interaction prompts and the stealth eye.
    ZO_PostHook(RETICLE, "UpdateHiddenState", function()
        if self.active then
            self.originalHidden = self.texture:IsHidden()
            self.texture:SetHidden(true)
        end
    end)
end
function O.ReticleReplacement.SetActive(active)
    local self = O.ReticleReplacement
    if not self.texture or self.active == active then return end
    self.active = active
    if active then
        self.originalHidden = self.texture:IsHidden()
        self.texture:SetHidden(true)
    else
        self.texture:SetHidden(self.originalHidden)
        RETICLE:UpdateHiddenState()
    end
end
