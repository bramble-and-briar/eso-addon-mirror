local ADDON_NAME = "NirnsteelUI"
local EVENT_NAMESPACE = ADDON_NAME .. "_InteractionPrompt"

Nirnsteel_UI = Nirnsteel_UI or {}
local InteractionPrompt = {}
Nirnsteel_UI.InteractionPrompt = InteractionPrompt

local function Settings()
    return Nirnsteel_UI.Settings:GetInteractionPrompt()
end

local function CaptureLayout(control, captureAlignment)
    local layout = { control = control, anchors = {} }
    for index = 0, control:GetNumAnchors() - 1 do
        local valid, point, relativeTo, relativePoint, x, y = control:GetAnchor(index)
        if valid then
            layout.anchors[#layout.anchors + 1] = { point, relativeTo, relativePoint, x, y }
        end
    end
    if captureAlignment then
        layout.alignment = control:GetHorizontalAlignment()
        layout.font = control:GetFont()
        layout.width, layout.height = control:GetDesiredWidth(), control:GetDesiredHeight()
    end
    return layout
end

function InteractionPrompt:RestorePromptLayout()
    if not self.promptLayout then return end
    for _, layout in ipairs(self.promptLayout) do
        local control = layout.control
        control:ClearAnchors()
        for _, anchor in ipairs(layout.anchors) do
            control:SetAnchor(anchor[1], anchor[2], anchor[3], anchor[4], anchor[5])
        end
        if layout.alignment ~= nil then
            control:SetHorizontalAlignment(layout.alignment)
            control:SetFont(layout.font)
            control:SetDimensions(layout.width, layout.height)
        end
        if layout.color then
            control:SetColor(layout.color[1], layout.color[2], layout.color[3], layout.color[4])
        end
    end
    self.native.interact:SetDimensions(self.originalWidth, self.originalHeight)
    self.divider:SetHidden(true)
    self.geometry = nil
    self.promptLayout = nil
end

function InteractionPrompt:CreateDivider()
    if self.divider then return end
    local parent = self.native.interact
    self.divider = WINDOW_MANAGER:CreateControl(nil, parent, CT_TEXTURE)
    self.divider:SetWidth(1)
    self.divider:SetAnchor(LEFT, self.native.interactKeybindButton, RIGHT, 9, 0)
    self.divider:SetDrawLayer(DL_BACKGROUND)
    self.divider:SetMouseEnabled(false)
end

function InteractionPrompt:UpdatePromptGeometry()
    if not self.promptLayout or self.updatingGeometry then return end
    self.updatingGeometry = true
    local native = self.native
    local context, key = native.interactContext, native.interactKeybindButton
    local name = context:GetText() or ""
    local hasName = name ~= ""
    local maxWidth = IsInGamepadPreferredMode() and 320 or 260
    local nameWidth = hasName and math.min(maxWidth, context:GetStringWidth(name)) or 0
    if context:GetDesiredWidth() ~= nameWidth then context:SetWidth(nameWidth) end
    local width = key:GetWidth() + (hasName and 18 + nameWidth or 0)
    local height = math.max(key:GetHeight(), context:GetTextHeight())
    if not self.geometry or self.geometry.width ~= width or self.geometry.height ~= height then
        native.interact:SetDimensions(width, height)
        native.additionalInfo:SetWidth(math.max(width, 220))
        self.divider:SetHeight(math.min(18, height))
        self.geometry = { width = width, height = height }
    end
    self.divider:SetHidden(not hasName)
    self.updatingGeometry = false
end

function InteractionPrompt:ApplyPromptLayout()
    if not Settings().centerPrompt then
        self:RestorePromptLayout()
        return
    end

    local native = self.native
    if not self.promptLayout then
        self.promptLayout =
        {
            CaptureLayout(native.interact),
            CaptureLayout(native.interactContext, true),
            CaptureLayout(native.interactKeybindButton),
            CaptureLayout(native.additionalInfo, true),
        }
        self.promptLayout[2].color = { native.interactContext:GetColor() }
        self.originalWidth, self.originalHeight = native.interact:GetDesiredWidth(), native.interact:GetDesiredHeight()
    end

    self:CreateDivider()
    -- Keep ESO's real binding/action control and its crime, lock and quest states.
    native.interact:ClearAnchors()
    native.interact:SetAnchor(TOP, native.reticleTexture, CENTER, 0, 12)
    native.interactKeybindButton:ClearAnchors()
    native.interactKeybindButton:SetAnchor(LEFT, native.interact, LEFT, 0, 0)
    native.interactContext:ClearAnchors()
    native.interactContext:SetAnchor(LEFT, native.interactKeybindButton, RIGHT, 18, 0)
    native.interactContext:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    native.interactContext:SetHeight(0)
    local gamepad = IsInGamepadPreferredMode()
    native.interactContext:SetFont(gamepad and "$(MEDIUM_FONT)|22|soft-shadow-thin" or "$(MEDIUM_FONT)|18|soft-shadow-thin")
    native.additionalInfo:ClearAnchors()
    native.additionalInfo:SetAnchor(TOP, native.interact, BOTTOM, 0, 12)
    native.additionalInfo:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    native.additionalInfo:SetHeight(0)
    native.additionalInfo:SetFont(gamepad and "$(MEDIUM_FONT)|20|soft-shadow-thin" or "$(MEDIUM_FONT)|16|soft-shadow-thin")
    local themes = Nirnsteel_UI.Themes
    if themes then
        native.interactContext:SetColor(themes:Color("body", 0.83, 0.87, 0.89, 1))
        self.divider:SetColor(themes:Color("highlight", 0.56, 0.65, 0.70, 0.65))
    end
    self:UpdatePromptGeometry()
end

function InteractionPrompt:Initialize()
    if self.native then return true end
    if not RETICLE or not RETICLE.reticleTexture or not RETICLE.interact
        or not RETICLE.interactContext or not RETICLE.interactKeybindButton
        or not RETICLE.additionalInfo then
        return false
    end

    self.native = RETICLE
    ZO_PostHook(self.native, "ApplyPlatformStyle", function()
        if self.promptLayout then
            -- Platform styling just supplied new native fonts. Restore these
            -- rather than the previous input mode's fonts when disabled.
            self.promptLayout[2].font = self.native.interactContext:GetFont()
            self.promptLayout[4].font = self.native.additionalInfo:GetFont()
        end
        self:ApplyPromptLayout()
    end)
    ZO_PostHook(self.native, "UpdateInteractText", function()
        if self.promptLayout and not self.native.interact:IsHidden() then
            self:UpdatePromptGeometry()
        end
    end)
    return true
end

function InteractionPrompt:RefreshSettings()
    if not self:Initialize() then return end
    self:ApplyPromptLayout()
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE .. "_Loaded", EVENT_ADD_ON_LOADED)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED, function()
        InteractionPrompt:RefreshSettings()
    end)
    InteractionPrompt:RefreshSettings()
end

EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_Loaded", EVENT_ADD_ON_LOADED, OnAddOnLoaded)
