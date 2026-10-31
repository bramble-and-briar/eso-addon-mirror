local ADDON_NAME = "NirnsteelUI"
local NAME = ADDON_NAME .. "_MagmaArmorIndicator"
local BASE_ABILITY_ID = 15957
local WIDTH, HEIGHT = 480, 96
local FRAME_COUNT, COLUMNS, ROWS = 32, 4, 8
local LOOP_MS, ERUPTION_MS, PREVIEW_MS = 1600, 900, 6000

Nirnsteel_UI = Nirnsteel_UI or {}
local Indicator = { abilityIds = { [BASE_ABILITY_ID] = true } }
Nirnsteel_UI.MagmaArmorIndicator = Indicator

local function Settings() return Nirnsteel_UI.Settings:GetMagmaArmorIndicator() end
local function Clamp(value, low, high) return math.max(low, math.min(high, tonumber(value) or low)) end

function Indicator:BuildAbilityIds()
    local hasProgression, progression = GetAbilityProgressionXPInfoFromAbilityId(BASE_ABILITY_ID)
    if not hasProgression then return end
    for morph = 0, 2 do
        for rank = 1, 4 do
            local id = GetAbilityProgressionAbilityId(progression, morph, rank)
            if id and id > 0 then self.abilityIds[id] = true end
        end
    end
end

function Indicator:ReadState()
    if self.deactivated or IsUnitDead("player") then return false end
    local now = GetFrameTimeMilliseconds()
    for index = 1, GetNumBuffs("player") do
        local _, began, ending, _, _, _, _, _, _, _, id, _, castByPlayer = GetUnitBuffInfo("player", index)
        -- Magma Shell can shield other players. Only the player's own armor
        -- effect counts; an ally's shield must never light this indicator.
        if self.abilityIds[id] and castByPlayer == true and ending and ending * 1000 > now then
            return true, math.min(now, (tonumber(began) or now / 1000) * 1000)
        end
    end
    return false
end

local function SetFrame(texture, frame)
    if texture.frame == frame then return end
    texture.frame = frame
    local column, row = frame % COLUMNS, math.floor(frame / COLUMNS)
    texture:SetTextureCoords(column / COLUMNS, (column + 1) / COLUMNS, row / ROWS, (row + 1) / ROWS)
end

function Indicator:CreateView()
    if self.root then return end
    local root = WINDOW_MANAGER:CreateTopLevelWindow(NAME)
    self.root = root
    root:SetDimensions(WIDTH, HEIGHT)
    root:SetDrawTier(DT_HIGH)
    root:SetClampedToScreen(true)
    root:SetMouseEnabled(false)
    root:SetHidden(true)
    local function Texture(file, level, additive)
        local texture = WINDOW_MANAGER:CreateControl(nil, root, CT_TEXTURE)
        texture:SetAnchorFill(root)
        texture:SetTexture(Nirnsteel_UI:GetAssetPath("ui/magma/" .. file .. "_dxt5.dds"))
        texture:SetDrawLayer(DL_ARTWORK)
        texture:SetDrawLevel(level)
        texture:SetMouseEnabled(false)
        if additive then texture:SetBlendMode(TEX_BLEND_MODE_ADD) end
        return texture
    end
    self.rocks = Texture("magma_rocks", 1)
    self.flow = Texture("magma_flow", 2, true)
    self.eruption = Texture("magma_eruption", 3)
    self.eruption:ClearAnchors()
    self.eruption:SetDimensions(WIDTH, 240)
    self.eruption:SetAnchor(BOTTOM, root, CENTER, 0, 38)
    self.eruption:SetHidden(true)
    SetFrame(self.flow, 0)
    SetFrame(self.eruption, 0)
    self.label = WINDOW_MANAGER:CreateControl(nil, root, CT_LABEL)
    self.label:SetAnchor(CENTER, root, CENTER, 0, 38)
    self.label:SetFont("$(BOLD_FONT)|15|soft-shadow-thick")
    self.label:SetColor(1, 0.76, 0.42, 1)
    self.label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.label:SetWidth(WIDTH)
    self.label:SetMouseEnabled(false)
    self.label:SetText("DRAG TO MOVE")
    root:SetHandler("OnMouseDown", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and self.positioning then
            control:SetMovable(true)
            control:StartMoving()
        end
    end)
    root:SetHandler("OnMouseUp", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then control:StopMovingOrResizing() end
    end)
    root:SetHandler("OnMoveStop", function(control)
        control:SetMovable(false)
        local x, y = control:GetCenter()
        local centerX = GuiRoot:GetCenter()
        local settings = Settings()
        settings.customPosition, settings.x, settings.y = true, x - centerX, y - GuiRoot:GetBottom()
        self:ApplyLayout()
    end)
end

function Indicator:ApplyLayout()
    local settings = Settings()
    self.root:ClearAnchors()
    if not settings.customPosition and ZO_ActionBar1 then
        self.root:SetAnchor(CENTER, ZO_ActionBar1, BOTTOM, 0, 18)
    else
        self.root:SetAnchor(CENTER, GuiRoot, BOTTOM, tonumber(settings.x) or 0, tonumber(settings.y) or -48)
    end
    self.root:SetScale(Clamp(settings.scale, 60, 180) / 100)
    self.root:SetAlpha(Clamp(settings.opacity, 20, 100) / 100)
end

function Indicator:Animate()
    local settings = Settings()
    local elapsed = math.max(0, GetFrameTimeMilliseconds() - self.displayStart)
    local intensity = Clamp(settings.animationIntensity, 0, 150) / 100
    SetFrame(self.flow, intensity > 0 and math.floor(elapsed / LOOP_MS * FRAME_COUNT) % FRAME_COUNT or 8)
    local pulse = intensity > 0 and math.sin(elapsed / LOOP_MS * 2 * math.pi) * 0.09 * intensity or 0
    self.flow:SetAlpha(math.min(1, 0.72 + intensity * 0.12 + pulse))
    local erupting = settings.activationBurst and intensity > 0 and elapsed < ERUPTION_MS
    self.eruption:SetHidden(not erupting)
    if erupting then
        SetFrame(self.eruption, math.min(FRAME_COUNT - 1, math.floor(elapsed / ERUPTION_MS * FRAME_COUNT)))
        self.eruption:SetAlpha(math.min(1, 0.65 + intensity * 0.35))
    end
end

function Indicator:Update()
    local settings, now = Settings(), GetFrameTimeMilliseconds()
    local active, began = false, nil
    if settings.enabled then active, began = self:ReadState() end
    self.active, self.liveStart = active, began
    if self.previewStart and now - self.previewStart >= PREVIEW_MS then self.previewStart = nil end
    self.positioning = settings.enabled and settings.unlocked and self.settingsPanelVisible and not self.deactivated or false
    if self.positioning and not self.positioningStart then self.positioningStart = now end
    if not self.positioning then self.positioningStart = nil end
    local preview = settings.enabled and self.previewStart ~= nil and not self.deactivated
    local hud = SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui")
    local visible = settings.enabled and not self.deactivated and (preview or self.positioning or (active and hud))
    self.root:SetHidden(not visible)
    self.root:SetMouseEnabled(self.positioning)
    if visible then
        self.displayStart = preview and self.previewStart or (self.positioning and self.positioningStart or self.liveStart)
        self.label:SetHidden(not self.positioning)
        self:Animate()
        self.root:SetHandler("OnUpdate", Clamp(settings.animationIntensity, 0, 150) > 0 and function() self:Animate() end or nil)
    else
        self.root:SetHandler("OnUpdate", nil)
    end
    -- A timed buff drives visibility. Merely slotting this ultimate needs no
    -- polling, and a bar swap cannot end an armor effect that is still active.
    local polling = settings.enabled and not self.deactivated and (active or preview or self.positioning)
    if polling and not self.polling then
        EVENT_MANAGER:RegisterForUpdate(NAME .. "_State", 100, function() self:Update() end)
    elseif not polling and self.polling then
        EVENT_MANAGER:UnregisterForUpdate(NAME .. "_State")
    end
    self.polling = polling
end

function Indicator:RefreshSettings()
    self:CreateView()
    if not Settings().enabled then
        self.previewStart = nil
        EVENT_MANAGER:UnregisterForUpdate(NAME .. "_Rescan")
    end
    self:ApplyLayout()
    self:Update()
end

function Indicator:Preview()
    if not Settings().enabled then return end
    self.previewStart = GetFrameTimeMilliseconds()
    self:RefreshSettings()
end

function Indicator:SetSettingsPanelVisible(visible)
    self.settingsPanelVisible = visible == true
    if not visible then self.previewStart = nil end
    if self.root then self:Update() end
end

function Indicator:RegisterEffectEvents()
    self.registeredEffects = self.registeredEffects or {}
    for id in pairs(self.abilityIds) do
        if not self.registeredEffects[id] then
            local namespace = NAME .. "_Effect_" .. id
            EVENT_MANAGER:RegisterForEvent(namespace, EVENT_EFFECT_CHANGED, function()
                if not Settings().enabled or self.deactivated then return end
                self:Update()
                -- Some buff snapshots settle just after the effect event.
                EVENT_MANAGER:RegisterForUpdate(NAME .. "_Rescan", 50, function()
                    EVENT_MANAGER:UnregisterForUpdate(NAME .. "_Rescan")
                    self:Update()
                end)
            end)
            EVENT_MANAGER:AddFilterForEvent(namespace, EVENT_EFFECT_CHANGED,
                REGISTER_FILTER_UNIT_TAG, "player", REGISTER_FILTER_ABILITY_ID, id)
            self.registeredEffects[id] = true
        end
    end
end

function Indicator:RegisterEvents()
    self:RegisterEffectEvents()
    for _, event in ipairs({ EVENT_EFFECTS_FULL_UPDATE, EVENT_PLAYER_ALIVE, EVENT_PLAYER_DEAD }) do
        EVENT_MANAGER:RegisterForEvent(NAME, event, function() self:Update() end)
    end
    for _, event in ipairs({ EVENT_SCREEN_RESIZED, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED }) do
        EVENT_MANAGER:RegisterForEvent(NAME, event, function() self:ApplyLayout() end)
    end
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_DEACTIVATED, function()
        self.deactivated, self.previewStart = true, nil
        EVENT_MANAGER:UnregisterForUpdate(NAME .. "_Rescan")
        self:Update()
    end)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, function()
        self.deactivated = false
        self:BuildAbilityIds()
        self:RegisterEffectEvents()
        self:RefreshSettings()
    end)
end

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    Indicator:BuildAbilityIds()
    Indicator:RefreshSettings()
    Indicator:RegisterEvents()
end)
