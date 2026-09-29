-- Colors are independent of position overrides. Only explicit visual leaves are tinted.
local MH = MovableHUD
MH.colorTargets = {
    {"health", "Health Bar", {"ZO_PlayerAttributeHealthBarLeft", "ZO_PlayerAttributeHealthBarRight"}, {0.8, 0.1, 0.1}},
    {"magicka", "Magicka Bar", {"ZO_PlayerAttributeMagickaBar"}, {0.15, 0.35, 1}},
    {"stamina", "Stamina Bar", {"ZO_PlayerAttributeStaminaBar"}, {0.2, 0.8, 0.15}},
    {"mount", "Mount Stamina Bar", {"ZO_PlayerAttributeMountStaminaBar"}, {0.8, 0.65, 0.2}},
    {"werewolf", "Werewolf Timer Bar", {"ZO_PlayerAttributeWerewolfBar"}, {0.7, 0.5, 0.2}},
    {"siegehealth", "Siege Health Bar", {"ZO_PlayerAttributeSiegeHealthBarLeft", "ZO_PlayerAttributeSiegeHealthBarRight"}, {0.8, 0.5, 0.2}},
    {"boss", "Boss Health Bar", {"ZO_BossBarHealthBarLeft", "ZO_BossBarHealthBarRight"}, {0.8, 0.1, 0.1}},
    {"reticle", "Reticle", {"ZO_ReticleContainerReticle"}, {1, 1, 1}},
    {"subtitles", "Subtitle Text", {"ZO_SubtitlesText"}, {1, 1, 1}},
    {"interact", "Interaction Text", {"ZO_ReticleContainerInteractContext", "ZO_ReticleContainerInteractAdditionalInfo"}, {1, 1, 1}},
    {"noninteract", "Non-interaction Text", {"ZO_ReticleContainerNonInteractText"}, {1, 1, 1}},
    {"combattips", "Combat Tip Text", {"ZO_ActiveCombatTipsTipTipText"}, {1, 1, 1}},
}
local captured = {}
local outlineDefaults = {0.35, 0.85, 1}
local function Channel(v, fallback)
    v = tonumber(v)
    if not v or v ~= v then return fallback end
    return math.max(0, math.min(1, v))
end
local function Same(a, b)
    return a and b and math.abs(a[1]-b[1]) < .0001
        and math.abs(a[2]-b[2]) < .0001 and math.abs(a[3]-b[3]) < .0001
end
local function Read(c)
    local r,g,b,a = c:GetColor()
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return nil end
    return {r,g,b}, a or 1
end
local baseNormalize = MH.NormalizeSavedVariables
function MH:NormalizeSavedVariables()
    baseNormalize(self)
    if type(self.saved.colors) ~= "table" then self.saved.colors = {} end
    for _, entry in ipairs(self.colorTargets) do
        local s = self.saved.colors[entry[1]]
        if type(s) ~= "table" then s = {}; self.saved.colors[entry[1]] = s end
        s.enabled = s.enabled == true
        for i = 1, 3 do s[i] = Channel(s[i], entry[4][i]) end
    end
    if type(self.saved.outlineColor) ~= "table" then self.saved.outlineColor = {} end
    for i = 1, 3 do self.saved.outlineColor[i] = Channel(self.saved.outlineColor[i], outlineDefaults[i]) end
    self.saved.schemaVersion = 6
end
local function Restore(c, state)
    local rgb, alpha = Read(c)
    if Same(rgb, state.applied) then
        c:SetColor(state.base[1], state.base[2], state.base[3], alpha)
    end
end
function MH:ApplyColors()
    if not self.saved or not self.saved.colors then return end
    local active = {}
    for _, entry in ipairs(self.colorTargets) do
        local s = self.saved.colors[entry[1]]
        if s.enabled then
            for _, name in ipairs(entry[3]) do
                local c = _G[name]
                if c and c.GetColor and c.SetColor then
                    pcall(function()
                        if c.IsHidden and c:IsHidden() then return end
                        local rgb, alpha = Read(c)
                        if not rgb then return end
                        active[c] = true
                        local state = captured[c]
                        if not state then state = {base = rgb}; captured[c] = state
                        elseif not Same(rgb, state.applied) then state.base = rgb end
                        if not Same(rgb, s) then c:SetColor(s[1], s[2], s[3], alpha) end
                        state.applied = {s[1], s[2], s[3]}
                    end)
                end
            end
        end
    end
    for c, state in pairs(captured) do
        if not active[c] and pcall(Restore, c, state) then captured[c] = nil end
    end
end
function MH:RefreshOutlineColors()
    if not self.saved or not self.saved.outlineColor then return end
    local rgb = self.saved.outlineColor
    for _, preview in pairs(self.previewControls or {}) do
        local parts = preview.movableHUDColorParts
        if parts then
            parts.fill:SetColor(rgb[1], rgb[2], rgb[3], .10)
            for _, border in ipairs(parts.borders) do border:SetColor(rgb[1], rgb[2], rgb[3], .95) end
            -- White labels stay legible regardless of the outline color.
        end
    end
end
local basePreview = MH.CreatePreviewControl
function MH:CreatePreviewControl(key)
    local existed = self.previewControls and self.previewControls[key]
    local c = basePreview(self, key)
    if not existed then self:RefreshOutlineColors() end
    return c
end
function MH:ResetColors()
    for _, entry in ipairs(self.colorTargets) do
        local s = self.saved.colors[entry[1]]
        s.enabled = false
        for i = 1, 3 do s[i] = entry[4][i] end
    end
    for i = 1, 3 do self.saved.outlineColor[i] = outlineDefaults[i] end
    self:ApplyColors()
    self:RefreshOutlineColors()
end
local baseHooks = MH.InstallHooks
function MH:InstallHooks()
    baseHooks(self)
    EVENT_MANAGER:RegisterForUpdate(self.name .. "_ColorGuard", 250, function() MH:ApplyColors() end)
end
local baseResetAll = MH.ResetAll
function MH:ResetAll()
    baseResetAll(self)
    self:ResetColors()
end
function MH:AddColorSettings(panel, library)
    local function RefreshPanel()
        zo_callLater(function()
            if panel.selected and panel.Select then panel.selected=false;panel:Select() end
        end, 0)
    end
    local function Sliders(settings, label, defaults, refresh, disabled)
        for i, channel in ipairs({"Red", "Green", "Blue"}) do
            local index = i
            panel:AddSetting({type=library.ST_SLIDER, label=label .. " - " .. channel,
                tooltip="RGB color channel. 0 removes this color; 100 uses its full strength.",
                min=0, max=100, step=1, format="%.0f", unit="%", default=defaults[index]*100,
                getFunction=function() return math.floor(settings[index]*100+.5) end,
                setFunction=function(value) settings[index]=Channel((tonumber(value) or 0)/100,defaults[index]);refresh() end,
                disable=disabled})
        end
    end
    panel:AddSetting({type=library.ST_SECTION,label="Placement Outline Color"})
    Sliders(self.saved.outlineColor,"Outline",outlineDefaults,function() self:RefreshOutlineColors() end)
    panel:AddSetting({type=library.ST_BUTTON,label="Restore outline color",buttonText="Reset",
        clickHandler=function()
            for i=1,3 do self.saved.outlineColor[i]=outlineDefaults[i] end
            self:RefreshOutlineColors()
            RefreshPanel()
        end})
    panel:AddSetting({type=library.ST_LABEL,label="HUD colors are optional and independent of position. Custom colors replace ESO's state-based tint on the selected visual; animation opacity is preserved. Only the listed bars and text support color overrides."})
    for _, entry in ipairs(self.colorTargets) do
        local s = self.saved.colors[entry[1]]
        local defaults = entry[4]
        panel:AddSetting({type=library.ST_SECTION,label=entry[2] .. " Color"})
        panel:AddSetting({type=library.ST_CHECKBOX,label="Enable custom color",default=false,
            getFunction=function() return s.enabled end,
            setFunction=function(value) s.enabled=value==true;self:ApplyColors() end})
        Sliders(s,entry[2],defaults,function() self:ApplyColors() end,function() return not s.enabled end)
        panel:AddSetting({type=library.ST_BUTTON,label="Restore native color",buttonText="Reset",
            clickHandler=function() s.enabled=false;for i=1,3 do s[i]=defaults[i] end;self:ApplyColors();RefreshPanel() end})
    end
    panel:AddSetting({type=library.ST_BUTTON,label="Restore all colors",buttonText="Reset Colors",
        clickHandler=function() self:ResetColors();RefreshPanel() end})
end
