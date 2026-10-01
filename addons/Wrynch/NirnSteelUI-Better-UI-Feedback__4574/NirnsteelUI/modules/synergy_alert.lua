local ADDON_NAME = "NirnsteelUI"
local EVENT_NAMESPACE = ADDON_NAME .. "_SynergyAlert"

Nirnsteel_UI = Nirnsteel_UI or {}
local SynergyAlert = {}
Nirnsteel_UI.SynergyAlert = SynergyAlert

local GLOW_TEXTURE = "EsoUI/Art/HUD/Gamepad/gp_skillGlow.dds"
local BORDER_TEXTURE = "EsoUI/Art/ActionBar/actionslot_normal.dds"
local ICON_SIZE = 112
local EMBLEM_SIZE = 144
local DETAILS_Y = 148
local FALLBACK_ICON = "EsoUI/Art/Icons/icon_missing.dds"
local ENTRANCE_MS = 300
local PULSE_MS = 2400
local PREVIEW_MS = 4000

local function Settings()
    return Nirnsteel_UI.Settings:GetSynergyAlert()
end

local function UsesHUDEditor()
    return Nirnsteel_UI.HUDEditor and Nirnsteel_UI.HUDEditor:IsAvailable()
end

local function IsUnlocked()
    return not UsesHUDEditor() and Settings().unlocked == true
end

local function Clamp(value, low, high)
    return math.max(low, math.min(high, tonumber(value) or low))
end

local function GetIntensity()
    return Clamp(Settings().animationIntensity, 0, 160) / 100
end

local function GetDefaultOffset()
    return IsInGamepadPreferredMode() and ZO_COMMON_INFO_DEFAULT_GAMEPAD_BOTTOM_OFFSET_Y
        or ZO_COMMON_INFO_DEFAULT_KEYBOARD_BOTTOM_OFFSET_Y
end

-- Reuse the ability slots' textured frame above the synergy artwork.
local function CreateIconBorder(parent)
    local border = WINDOW_MANAGER:CreateControl(nil, parent, CT_TEXTURE)
    border:SetAnchorFill(parent)
    border:SetTexture(BORDER_TEXTURE)
    border:SetColor(1, 1, 1, 1)
    border:SetDrawLayer(DL_ARTWORK)
    border:SetDrawLevel(2)
    return border
end

function SynergyAlert:StopAnimation(view)
    view:SetHandler("OnUpdate", nil)
    view.frame:SetAlpha(1)
    view.frame:SetTransformScale(1)
    view.hero:SetTransformScale(1)
    view.hero:SetAlpha(1)
    view.glow:SetAlpha(0.36)
    view.glow:SetTransformScale(1)
end

function SynergyAlert:UpdateAnimation(view)
    local intensity = GetIntensity()
    local elapsed = math.max(0, GetFrameTimeMilliseconds() - view.entranceStartMS)
    local progress = math.min(1, elapsed / ENTRANCE_MS)
    local pulse = (1 - math.cos(math.max(0, elapsed - ENTRANCE_MS) / PULSE_MS * 2 * math.pi)) * 0.5
    local eased = progress * progress * (3 - 2 * progress)
    -- Animate opacity only: thin borders and artwork never change size or position.
    view.hero:SetAlpha(eased)
    view.glow:SetAlpha(eased * (0.36 + pulse * 0.18 * intensity))
end

function SynergyAlert:StartAnimation(view, restart)
    if restart or not view.entranceStartMS then
        view.entranceStartMS = GetFrameTimeMilliseconds()
    end
    if view:IsControlHidden() or GetIntensity() == 0 then
        self:StopAnimation(view)
        return
    end
    self:UpdateAnimation(view)
    view:SetHandler("OnUpdate", function() self:UpdateAnimation(view) end)
end

function SynergyAlert:CreateView(name, parent)
    local view
    if parent then
        view = WINDOW_MANAGER:CreateControl(name, parent, CT_CONTROL)
    else
        view = WINDOW_MANAGER:CreateTopLevelWindow(name)
        view:SetDrawTier(DT_HIGH)
    end
    view:SetHidden(true)
    view:SetClampedToScreen(true)
    view:SetMouseEnabled(false)

    local frame = WINDOW_MANAGER:CreateControl(nil, view, CT_CONTROL)
    frame:SetAnchorFill(view)
    frame:SetTransformNormalizedOriginPoint(0.5, 0.5)
    view.frame = frame

    -- A floating emblem, with no full-width panel behind the text.
    local emblem = WINDOW_MANAGER:CreateControl(nil, frame, CT_CONTROL)
    emblem:SetDimensions(EMBLEM_SIZE, EMBLEM_SIZE)
    emblem:SetAnchor(TOP, frame, TOP, 0, 0)
    view.emblem = emblem

    view.glow = WINDOW_MANAGER:CreateControl(nil, emblem, CT_TEXTURE)
    view.glow:SetDimensions(176, 176)
    view.glow:SetAnchor(CENTER, emblem, CENTER, 0, 0)
    view.glow:SetTexture(GLOW_TEXTURE)
    view.glow:SetColor(0.36, 0.75, 1, 1)
    view.glow:SetBlendMode(TEX_BLEND_MODE_ADD)
    view.glow:SetDrawLayer(DL_BACKGROUND)
    view.glow:SetDrawLevel(0)
    view.glow:SetTransformNormalizedOriginPoint(0.5, 0.5)

    view.hero = WINDOW_MANAGER:CreateControl(nil, emblem, CT_CONTROL)
    view.hero:SetDimensions(ICON_SIZE, ICON_SIZE)
    view.hero:SetAnchor(CENTER, emblem, CENTER, 0, 0)
    view.hero:SetTransformNormalizedOriginPoint(0.5, 0.5)
    view.border = CreateIconBorder(view.hero)
    view.icon = WINDOW_MANAGER:CreateControl(nil, view.hero, CT_TEXTURE)
    view.icon:SetDimensions(ICON_SIZE, ICON_SIZE)
    view.icon:SetAnchor(CENTER, view.hero, CENTER, 0, 0)
    view.icon:SetColor(1, 1, 1, 1)
    view.icon:SetDrawLayer(DL_ARTWORK)
    view.icon:SetDrawLevel(1)

    -- One centered action row keeps the binding and caption together below the icon.
    view.details = WINDOW_MANAGER:CreateControl(nil, frame, CT_CONTROL)
    view.details:SetAnchor(TOP, frame, TOP, 0, DETAILS_Y)
    view.label = WINDOW_MANAGER:CreateControl(nil, view.details, CT_LABEL)
    view.label:SetColor(0.91, 0.95, 1, 1)
    view.label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    view.label:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    view.key = WINDOW_MANAGER:CreateControlFromVirtual(name .. "Key", view.details, "ZO_KeybindButton")
    view.key:SetKeybind("USE_SYNERGY")
    view.key:SetMouseEnabled(false)
    view.key:SetAnchor(LEFT, view.details, LEFT, 0, 0)
    view.label:SetAnchor(LEFT, view.key, RIGHT, 8, 0)
    view.key:SetDrawLayer(DL_CONTROLS)
    view.key:SetDrawLevel(7)

    view:SetHandler("OnEffectivelyHidden", function() self:StopAnimation(view) end)
    view:SetHandler("OnEffectivelyShown", function() self:StartAnimation(view, false) end)
    return view
end

function SynergyAlert:LayoutView(view)
    if view.layingOut or view.moving then return end
    view.layingOut = true
    local gamepad = IsInGamepadPreferredMode()
    local position = Nirnsteel_UI.Settings:GetSynergyAlertPosition()
    view:SetScale(Clamp(Settings().scale, 70, 160) / 100)
    view:SetAlpha(Clamp(Settings().opacity, 20, 100) / 100)
    view:ClearAnchors()
    view:SetAnchor(BOTTOM, GuiRoot, BOTTOM, position.custom and position.x or 0,
        position.custom and position.y or GetDefaultOffset())

    if view.gamepadStyle ~= gamepad then
        view.gamepadStyle = gamepad
        ApplyTemplateToControl(view.key, gamepad and "ZO_KeybindButton_Gamepad_Template" or "ZO_KeybindButton_Keyboard_Template")
    end
    view.label:SetFont(gamepad and "$(BOLD_FONT)|20|thick-outline" or "$(BOLD_FONT)|18|thick-outline")
    -- Measure the caption before wrapping so short names don't leave an empty column.
    view.label:SetWidth(0)
    local textWidth = math.min(gamepad and 260 or 240, view.label:GetTextWidth())
    view.label:SetWidth(math.max(1, textWidth))
    view.label:SetHeight(0)
    local rowWidth = view.key:GetWidth() + 8 + view.label:GetWidth()
    local rowHeight = math.max(view.key:GetHeight(), view.label:GetTextHeight())
    view.details:SetDimensions(rowWidth, rowHeight)
    view:SetDimensions(math.max(EMBLEM_SIZE, rowWidth), DETAILS_Y + rowHeight + 4)
    if UsesHUDEditor() then
        if view == self.live then
            Nirnsteel_UI.HUDEditor:Apply("synergyAlert",view,{
                name="Nirnsteel Synergy", position=position,
                enabled=function() return Settings().enabled end,
                defaultAnchor=function(platform)
                    local y = platform == "gamepad" and ZO_COMMON_INFO_DEFAULT_GAMEPAD_BOTTOM_OFFSET_Y
                        or ZO_COMMON_INFO_DEFAULT_KEYBOARD_BOTTOM_OFFSET_Y
                    return ZO_Anchor:New(BOTTOM,GuiRoot,BOTTOM,0,y)
                end,
                replaces=function(control) return control == self.native.container end,
                preview=function(active)
                    self.hudEditorActive = active
                    if active then self:Preview() else self:StopPreview() end
                end,
            })
        else
            view:ClearAnchors()
            view:SetAnchor(BOTTOM,self.live,BOTTOM,0,0)
        end
    end
    view.bindingWidth, view.bindingHeight = view.key:GetWidth(), view.key:GetHeight()
    view.layingOut = false
end

function SynergyAlert:ApplyLayout()
    if not self.initialized then return end
    self:LayoutView(self.live)
    self:LayoutView(self.preview)
end

function SynergyAlert:SetNativeHidden(hidden)
    if hidden and not self.nativeHidden then
        self.previousContainerHidden = self.native.container:IsHidden()
        self.nativeHidden = true
        self.native.container:SetHidden(true)
    elseif not hidden and self.nativeHidden then
        self.nativeHidden = false
        self.native.container:SetHidden(self.previousContainerHidden)
    end
end

function SynergyAlert:SyncLive()
    if not self.initialized then return end
    local available, name, icon, prompt = GetCurrentSynergyInfo()
    local identity = available and ((name or "") .. "\031" .. (icon or "")) or nil
    local changed = identity ~= self.live.identity
    self.live.identity = identity
    if available then
        local texture = icon and icon ~= "" and icon or FALLBACK_ICON
        local caption = prompt and prompt ~= "" and prompt or zo_strformat("<<1>>", name)
        if self.live.texture ~= texture then
            self.live.texture = texture
            self.live.icon:SetTexture(texture)
        end
        if self.live.caption ~= caption then
            self.live.caption = caption
            self.live.label:SetText(caption)
            self:LayoutView(self.live)
        end
    end
    self.live:SetHidden(not Settings().enabled or not available or self.previewActive == true)
    if changed then
        self:StartAnimation(self.live, true)
    end
end

function SynergyAlert:StopPreview()
    EVENT_MANAGER:UnregisterForUpdate(EVENT_NAMESPACE .. "_Preview")
    if self.preview.moving then self.preview:StopMovingOrResizing() end
    self.previewActive = false
    self.previewPositioning = false
    self.preview:SetHidden(true)
    self.preview:SetMouseEnabled(false)
    self:StopAnimation(self.preview)
    self:SyncLive()
end

function SynergyAlert:Preview()
    if not self.initialized or not Settings().enabled then return end
    self.previewActive = true
    self.previewPositioning = self.hudEditorActive or (IsUnlocked() and self.settingsPanelVisible == true)
    -- A separate view means previews cannot overwrite native/live synergy state.
    self.preview.icon:SetTexture("EsoUI/Art/Icons/ability_healer_011.dds")
    self.preview.label:SetText("Nirnsteel Synergy")
    self:LayoutView(self.preview)
    self.live:SetHidden(true)
    self.preview:SetHidden(false)
    self.preview:SetMouseEnabled(IsUnlocked())
    self:StartAnimation(self.preview, true)
    EVENT_MANAGER:UnregisterForUpdate(EVENT_NAMESPACE .. "_Preview")
    if not self.previewPositioning then
        EVENT_MANAGER:RegisterForUpdate(EVENT_NAMESPACE .. "_Preview", PREVIEW_MS, function() self:StopPreview() end)
    end
end

function SynergyAlert:SetSettingsPanelVisible(visible)
    self.settingsPanelVisible = visible == true
    if not self.initialized then return end
    if self.settingsPanelVisible and Settings().enabled and IsUnlocked() then
        self:Preview()
    elseif not self.settingsPanelVisible and not self.hudEditorActive then
        self:StopPreview()
    end
end

function SynergyAlert:Initialize()
    if self.initialized then return true end
    if not SYNERGY or not SYNERGY.container then return false end
    self.native = SYNERGY
    -- Parenting to ESO's top level preserves scene, priority, and suppression rules.
    self.live = self:CreateView("Nirnsteel_UI_SynergyAlert", self.native.control)
    self.preview = self:CreateView("Nirnsteel_UI_SynergyAlertPreview")
    self.initialized = true

    ZO_PostHook(self.native, "OnSynergyAbilityChanged", function() self:SyncLive() end)
    ZO_PostHook(self.native, "ApplyTextStyle", function() self:ApplyLayout() end)
    -- Binding glyphs can change width without a platform-mode change.
    for _, view in ipairs({ self.live, self.preview }) do
        ZO_PostHookHandler(view.key, "OnRectChanged", function()
            -- A position-only notification must not re-anchor the alert mid-animation.
            if view.key:GetWidth() ~= view.bindingWidth or view.key:GetHeight() ~= view.bindingHeight then
                self:LayoutView(view)
            end
        end)
    end

    self.preview:SetHandler("OnMouseDown", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and IsUnlocked() then
            control.moving = true
            control:SetMovable(true)
            control:StartMoving()
        end
    end)
    self.preview:SetHandler("OnMouseUp", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then control:StopMovingOrResizing() end
    end)
    self.preview:SetHandler("OnMoveStop", function(control)
        control.moving = false
        control:SetMovable(false)
        local centerX = control:GetCenter()
        local rootCenterX = GuiRoot:GetCenter()
        Nirnsteel_UI.Settings:SetSynergyAlertPosition(centerX - rootCenterX, control:GetBottom() - GuiRoot:GetBottom())
        self:ApplyLayout()
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_Resize", EVENT_SCREEN_RESIZED, function() self:ApplyLayout() end)
    return true
end

function SynergyAlert:RefreshSettings()
    if not self:Initialize() then return end
    self:ApplyLayout()
    self:SetNativeHidden(Settings().enabled == true)
    if not Settings().enabled then
        self:StopPreview()
    elseif self.hudEditorActive then
        self:Preview()
    elseif IsUnlocked() and self.settingsPanelVisible then
        if not self.previewActive or not self.previewPositioning then
            self:Preview()
        else
            self:StartAnimation(self.preview, false)
        end
    elseif self.previewPositioning then
        self:StopPreview()
    elseif self.previewActive then
        self:StartAnimation(self.preview, false)
    end
    self:SyncLive()
    self:StartAnimation(self.live, false)
end

EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_Loaded", EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE .. "_Loaded", EVENT_ADD_ON_LOADED)
    SynergyAlert:RefreshSettings()
end)
EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_Activated", EVENT_PLAYER_ACTIVATED, function()
    SynergyAlert:RefreshSettings()
end)
