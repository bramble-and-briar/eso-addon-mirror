local ADDON_NAME = "NirnsteelUI"
local NAME = ADDON_NAME .. "_OverloadIndicator"
local BASE_ABILITY_ID = 24785
local WIDTH, HEIGHT = 480, 96
local ATLAS_COLUMNS, ATLAS_ROWS, FRAME_COUNT = 4, 8, 32
local BURST_MS, LOOP_MS, PREVIEW_MS = 720, 1600, 6000
local START_DELAY_MS = 500
local STRIKE_MS, IMPACT_MS = 640, 200
local STRIKE_WIDTH, STRIKE_HEIGHT = 176, 560

Nirnsteel_UI = Nirnsteel_UI or {}
local Indicator = { abilityIds = { [BASE_ABILITY_ID] = true } }
Nirnsteel_UI.OverloadIndicator = Indicator

local function Settings() return Nirnsteel_UI.Settings:GetOverloadIndicator() end
local function Clamp(value, low, high) return math.max(low, math.min(high, tonumber(value) or low)) end

function Indicator:BuildAbilityIds()
    -- Ask ESO for all ranks of the base skill and both morphs. Names are localized,
    -- and subclassing means that checking the player's class is insufficient.
    local hasProgression, progression = GetAbilityProgressionXPInfoFromAbilityId(BASE_ABILITY_ID)
    if not hasProgression then return end
    for morph = 0, 2 do
        for rank = 1, 4 do
            local abilityId = GetAbilityProgressionAbilityId(progression, morph, rank)
            if abilityId and abilityId > 0 then self.abilityIds[abilityId] = true end
        end
    end
end

function Indicator:ReadState()
    if self.deactivated or IsUnitDead("player") then return false, false end
    local slotted, active = false, false
    local categories = { HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP, GetActiveHotbarCategory() }
    local visited = {}
    for _, category in ipairs(categories) do
        if not visited[category] then
            visited[category] = true
            local slot = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1
            if self.abilityIds[GetSlotBoundId(slot, category)] then
                slotted = true
                if IsSlotToggled(slot, category) then active = true end
            end
        end
    end
    -- The player buff also survives a weapon swap to a bar with a different
    -- ultimate, and restores state after a reload without guessing from input.
    if not active then
        for index = 1, GetNumBuffs("player") do
            local _, _, _, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", index)
            if self.abilityIds[abilityId] then active = true; break end
        end
    end
    return active, slotted
end

local function SetFrame(texture, frame)
    if texture.frame == frame then return end
    texture.frame = frame
    local columns, rows = texture.atlasColumns or ATLAS_COLUMNS, texture.atlasRows or ATLAS_ROWS
    local column, row = frame % columns, math.floor(frame / columns)
    texture:SetTextureCoords(column / columns, (column + 1) / columns,
        row / rows, (row + 1) / rows)
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
    local function Texture(file, level, columns, rows)
        local texture = WINDOW_MANAGER:CreateControl(nil, root, CT_TEXTURE)
        texture.atlasColumns, texture.atlasRows = columns, rows
        texture:SetAnchorFill(root)
        texture:SetTexture(Nirnsteel_UI:GetAssetPath("ui/overload/" .. file .. "_dxt5.dds"))
        texture:SetBlendMode(TEX_BLEND_MODE_ADD)
        texture:SetDrawLayer(DL_ARTWORK)
        texture:SetDrawLevel(level)
        texture:SetMouseEnabled(false)
        SetFrame(texture, 0)
        return texture
    end
    self.loop = Texture("lightning_loop", 1)
    self.burst = Texture("lightning_burst", 2)
    self.strike = Texture("lightning_strike", 3, 8, 4)
    -- The tall entrance is a child of the movable indicator. Keep the root's
    -- small bounds so screen clamping and dragging never move the landing point.
    self.strike:ClearAnchors()
    self.strike:SetDimensions(STRIKE_WIDTH, STRIKE_HEIGHT)
    self.strike:SetAnchor(BOTTOM, root, CENTER, 0, 12)
    self.strike:SetHidden(true)
    self.label = WINDOW_MANAGER:CreateControl(nil, root, CT_LABEL)
    self.label:SetAnchor(CENTER, root, CENTER, 0, 31)
    self.label:SetFont("$(BOLD_FONT)|15|soft-shadow-thick")
    self.label:SetColor(0.7, 0.88, 1, 1)
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
    local elapsed = GetFrameTimeMilliseconds() - self.displayStart - START_DELAY_MS
    if elapsed < 0 then
        self.loop:SetAlpha(0)
        self.strike:SetHidden(true)
        self.burst:SetHidden(true)
        return
    end
    local intensity = Clamp(settings.animationIntensity, 0, 150) / 100
    local vertical = settings.verticalStrike ~= false and intensity > 0
    local impactElapsed = elapsed - (vertical and IMPACT_MS or 0)
    local loopElapsed = math.max(0, impactElapsed)
    local frame = intensity > 0 and math.floor(loopElapsed / LOOP_MS * FRAME_COUNT) % FRAME_COUNT or 8
    SetFrame(self.loop, frame)
    local pulse = intensity > 0 and math.sin(loopElapsed / 560) * 0.08 * intensity or 0
    local fade = intensity > 0 and math.min(1, loopElapsed / 160) or 1
    self.loop:SetAlpha(fade * (0.76 + pulse + intensity * 0.10))
    local strike = vertical and elapsed < STRIKE_MS
    self.strike:SetHidden(not strike)
    if strike then
        SetFrame(self.strike, math.min(FRAME_COUNT - 1, math.floor(elapsed / STRIKE_MS * FRAME_COUNT)))
        self.strike:SetAlpha(math.min(1, 0.55 + intensity * 0.45))
    end
    local burst = settings.activationBurst and intensity > 0 and impactElapsed >= 0 and impactElapsed < BURST_MS
    self.burst:SetHidden(not burst)
    if burst then
        SetFrame(self.burst, math.min(FRAME_COUNT - 1, math.floor(impactElapsed / BURST_MS * FRAME_COUNT)))
        self.burst:SetAlpha(math.min(1, 0.55 + intensity * 0.45))
    end
end

function Indicator:Update()
    local settings, now = Settings(), GetFrameTimeMilliseconds()
    local active, slotted = false, false
    if settings.enabled then active, slotted = self:ReadState() end
    if active and not self.active then self.liveStart = now end
    self.active = active
    if self.previewStart and now - self.previewStart >= PREVIEW_MS then self.previewStart = nil end
    self.positioning = settings.enabled and settings.unlocked and self.settingsPanelVisible and not self.deactivated or false
    local preview = settings.enabled and self.previewStart ~= nil and not self.deactivated
    if self.positioning and not self.positioningStart then self.positioningStart = now end
    if not self.positioning then self.positioningStart = nil end
    local hud = SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui")
    local visible = settings.enabled and not self.deactivated and (preview or self.positioning or (active and hud))
    self.root:SetMouseEnabled(self.positioning)
    self.root:SetHidden(not visible)
    if visible then
        self.displayStart = preview and self.previewStart or (self.positioning and self.positioningStart or self.liveStart)
        self.label:SetHidden(not self.positioning)
        self:Animate()
        -- Static mode and hidden HUDs have no frame callback. Atlas controls are
        -- allocated once; the animation only changes UVs and opacity.
        self.root:SetHandler("OnUpdate", Clamp(settings.animationIntensity, 0, 150) > 0 and function() self:Animate() end or nil)
    else
        self.root:SetHandler("OnUpdate", nil)
    end
    local polling = settings.enabled and not self.deactivated and (slotted or active or preview or self.positioning)
    if polling and not self.polling then
        EVENT_MANAGER:RegisterForUpdate(NAME .. "_State", 100, function() self:Update() end)
    elseif not polling and self.polling then
        EVENT_MANAGER:UnregisterForUpdate(NAME .. "_State")
    end
    self.polling = polling
end

function Indicator:RefreshSettings()
    self:CreateView()
    if not Settings().enabled then self.previewStart = nil end
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
    for abilityId in pairs(self.abilityIds) do
        if not self.registeredEffects[abilityId] then
            local namespace = NAME .. "_Effect_" .. abilityId
            EVENT_MANAGER:RegisterForEvent(namespace, EVENT_EFFECT_CHANGED, function() self:Update() end)
            EVENT_MANAGER:AddFilterForEvent(namespace, EVENT_EFFECT_CHANGED,
                REGISTER_FILTER_UNIT_TAG, "player", REGISTER_FILTER_ABILITY_ID, abilityId)
            self.registeredEffects[abilityId] = true
        end
    end
end

function Indicator:RegisterEvents()
    for _, event in ipairs({ EVENT_ACTION_SLOT_STATE_UPDATED, EVENT_ACTION_SLOT_UPDATED }) do
        EVENT_MANAGER:RegisterForEvent(NAME, event, function(_, slot)
            if slot == nil or slot == ACTION_BAR_ULTIMATE_SLOT_INDEX + 1 then self:Update() end
        end)
    end
    for _, event in ipairs({ EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED,
        EVENT_EFFECTS_FULL_UPDATE, EVENT_PLAYER_ALIVE, EVENT_PLAYER_DEAD }) do
        EVENT_MANAGER:RegisterForEvent(NAME, event, function() self:Update() end)
    end
    self:RegisterEffectEvents()
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_SCREEN_RESIZED, function() self:ApplyLayout() end)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function() self:ApplyLayout() end)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_DEACTIVATED, function()
        self.deactivated, self.previewStart = true, nil
        self:Update()
    end)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, function()
        self.deactivated = false
        -- Progression data can finish loading after EVENT_ADD_ON_LOADED.
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
