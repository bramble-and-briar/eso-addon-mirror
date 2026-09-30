-- ESO Adventurer Suite
-- Copyright (c) 2026 HoZayyBadazz. All Rights Reserved.
-- Proprietary source. Unauthorized redistribution, republication, rebranding,
-- or public distribution of modified/derivative versions is prohibited.
-- Private personal-use modifications are permitted. See LICENSE.txt.

-- v0.28.64 - native ESO Use Synergy layout preview cleanup.
-- No custom prompt, border, backdrop, label, or replacement artwork is drawn.
-- HUD Layout Mode always exposes ESO's stock ZO_Synergy controls so the native
-- icon frame, keybind button, action text, and platform styling can be moved
-- safely outside combat. Normal gameplay visibility remains controlled by ESO.

local EPC = ESOProgressionCoach
EPC.SynergyOverlay = EPC.SynergyOverlay or {}
local S = EPC.SynergyOverlay
local wm = WINDOW_MANAGER

local function num(value, fallback)
    local n = tonumber(value)
    if n == nil then n = tonumber(fallback) or 0 end
    return n
end

function S:GetNativeSynergy()
    local synergy = rawget(_G, "SYNERGY")
    if type(synergy) ~= "table" then return nil end
    return synergy
end

function S:GetNativeContainer()
    local synergy = self:GetNativeSynergy()
    return synergy and synergy.container or nil
end

function S:HasCustomPosition()
    return EPC.saved and EPC.saved.synergyOverlayCustom2861 == true
end

function S:GetRootCenter()
    if not GuiRoot then return 0, 0 end
    if type(GuiRoot.GetCenter) == "function" then
        local x, y = GuiRoot:GetCenter()
        return num(x, 0), num(y, 0)
    end
    local w = type(GuiRoot.GetWidth) == "function" and num(GuiRoot:GetWidth(), 0) or 0
    local h = type(GuiRoot.GetHeight) == "function" and num(GuiRoot:GetHeight(), 0) or 0
    return w * 0.5, h * 0.5
end

function S:GetDefaultBottomOffset()
    local offset = rawget(_G, "ZO_COMMON_INFO_DEFAULT_KEYBOARD_BOTTOM_OFFSET_Y")
    return num(offset, 0)
end

function S:RestoreNativeAnchor()
    local container = self:GetNativeContainer()
    if not container or type(container.ClearAnchors) ~= "function" or type(container.SetAnchor) ~= "function" then return false end
    if EPC.NativeHUDEditor and EPC.NativeHUDEditor.IsESOPositionOwner
        and EPC.NativeHUDEditor:IsESOPositionOwner(container) then return true end
    container:ClearAnchors()
    container:SetAnchor(BOTTOM, nil, BOTTOM, 0, self:GetDefaultBottomOffset())
    return true
end

function S:ApplySavedAnchor()
    local container = self:GetNativeContainer()
    if not container or type(container.ClearAnchors) ~= "function" or type(container.SetAnchor) ~= "function" then return false end
    if EPC.NativeHUDEditor and EPC.NativeHUDEditor.IsESOPositionOwner
        and EPC.NativeHUDEditor:IsESOPositionOwner(container) then return true end
    if not self:HasCustomPosition() then return false end
    container:ClearAnchors()
    container:SetAnchor(CENTER, GuiRoot, CENTER,
        num(EPC.saved.synergyOverlayOffsetX2861, 0),
        num(EPC.saved.synergyOverlayOffsetY2861, 0))
    return true
end

function S:GetCurrentOffset()
    if self:HasCustomPosition() then
        return num(EPC.saved.synergyOverlayOffsetX2861, 0), num(EPC.saved.synergyOverlayOffsetY2861, 0)
    end

    local container = self:GetNativeContainer()
    if container and type(container.GetCenter) == "function" then
        local x, y = container:GetCenter()
        x, y = tonumber(x), tonumber(y)
        if x and y and (x ~= 0 or y ~= 0) then
            local rootX, rootY = self:GetRootCenter()
            return x - rootX, y - rootY
        end
    end

    return 0, self:GetDefaultBottomOffset()
end

function S:NativeHasSynergy()
    if type(GetCurrentSynergyInfo) == "function" then
        local ok, hasSynergy = pcall(GetCurrentSynergyInfo)
        if ok then return hasSynergy == true end
    end
    local synergy = self:GetNativeSynergy()
    if synergy and type(synergy.IsVisible) == "function" then
        local ok, visible = pcall(synergy.IsVisible, synergy)
        if ok then return visible == true end
    end
    return false
end

function S:GetPreviewText()
    local stringId = rawget(_G, "SI_BINDING_NAME_USE_SYNERGY")
    if stringId and type(GetString) == "function" then
        local ok, text = pcall(GetString, stringId)
        if ok and type(text) == "string" and text ~= "" then return text end
    end
    return "Use Synergy"
end

function S:ShowNativeLayoutPreview()
    local synergy = self:GetNativeSynergy()
    if not synergy then return false end

    -- Use the actual vanilla controls. Only provide preview text when no live
    -- synergy exists; the native key control already owns USE_SYNERGY and keeps
    if synergy.action and type(synergy.action.SetText) == "function" then
        synergy.action:SetText(self:GetPreviewText())
        if type(synergy.action.SetHidden) == "function" then synergy.action:SetHidden(false) end
    end

    if synergy.control and type(synergy.control.SetHidden) == "function" then
        -- Deliberately unhide only the stock top-level control. Do not change
        -- SHARED_INFORMATION_AREA's internal hidden state, so USE_SYNERGY cannot
        -- become logically active just because layout mode is displaying it.
        synergy.control:SetHidden(false)
    elseif type(synergy.SetHidden) == "function" then
        synergy:SetHidden(false)
    end

    self.previewing = true
    return true
end

function S:RestoreNativeVisibilityState()
    self.previewing = false
    local synergy = self:GetNativeSynergy()
    if not synergy then return end

    -- Ask ESO to rebuild the real prompt first. This restores the real action
    -- text/icon whenever a live synergy exists.
    if type(synergy.OnSynergyAbilityChanged) == "function" then
        synergy:OnSynergyAbilityChanged()
    end

    -- The layout preview directly unhides the native top-level. ESO's normal
    -- refresh does not always re-hide that direct override when UI mode closes,
    -- so explicitly remove the preview only when there is no real synergy.
    -- GetCurrentSynergyInfo is the authoritative API and does not depend on the
    -- visual state we temporarily changed for HUD Layout Mode.
    local hasLiveSynergy = false
    if type(GetCurrentSynergyInfo) == "function" then
        local ok, hasSynergy = pcall(GetCurrentSynergyInfo)
        hasLiveSynergy = ok and hasSynergy == true
    end

    if not hasLiveSynergy then
        if synergy.action and type(synergy.action.SetHidden) == "function" then
            synergy.action:SetHidden(true)
        end
        if synergy.control and type(synergy.control.SetHidden) == "function" then
            synergy.control:SetHidden(true)
        elseif type(synergy.SetHidden) == "function" then
            synergy:SetHidden(true)
        end
    end
end

function S:SyncMoverDimensions()
    if not self.mover then return end
    local container = self:GetNativeContainer()
    local width, height = 0, 0
    if container then
        if type(container.GetWidth) == "function" then width = num(container:GetWidth(), 0) end
        if type(container.GetHeight) == "function" then height = num(container:GetHeight(), 0) end
    end
    if width < 120 then width = 320 end
    if height < 35 then height = 60 end
    self.mover:SetDimensions(width, height)
end

function S:AnchorMoverToCurrentPosition()
    if not self.mover then return end
    local x, y = self:GetCurrentOffset()
    self.mover:ClearAnchors()
    self.mover:SetAnchor(CENTER, GuiRoot, CENTER, x, y)
end

function S:AnchorNativeToMover()
    if not self.mover then return false end
    local container = self:GetNativeContainer()
    if not container or type(container.ClearAnchors) ~= "function" or type(container.SetAnchor) ~= "function" then return false end
    container:ClearAnchors()
    container:SetAnchor(CENTER, self.mover, CENTER, 0, 0)
    return true
end

function S:SaveMoverPosition()
    if not EPC.saved or not self.mover then return end
    local x, y = self.mover:GetCenter()
    x, y = tonumber(x), tonumber(y)
    if not x or not y then return end
    local rootX, rootY = self:GetRootCenter()
    EPC.saved.synergyOverlayOffsetX2861 = x - rootX
    EPC.saved.synergyOverlayOffsetY2861 = y - rootY
    EPC.saved.synergyOverlayCustom2861 = true
end

function S:CreateMover()
    if self.mover then return end

    -- Intentionally invisible. The user sees and drags ESO's own synergy prompt.
    local mover = wm:CreateTopLevelWindow("EAS_SynergyNativeMover2863")
    mover:SetDimensions(320, 60)
    mover:SetClampedToScreen(true)
    mover:SetMouseEnabled(false)
    mover:SetMovable(false)
    mover:SetHidden(true)
    if type(mover.SetDrawTier) == "function" and rawget(_G, "DT_HIGH") then
        mover:SetDrawTier(DT_HIGH)
    end

    mover:SetHandler("OnMoveStart", function()
        self.dragging = true
        self:AnchorNativeToMover()
    end)

    mover:SetHandler("OnMoveStop", function()
        self.dragging = false
        self:SaveMoverPosition()
        self:AnchorNativeToMover()
    end)

    self.mover = mover
end

function S:RefreshLayoutMover()
    if not self.mover then return end

    if not self.layoutMode then
        self.mover:SetMouseEnabled(false)
        self.mover:SetMovable(false)
        self.mover:SetHidden(true)
        return
    end

    -- Always provide a safe out-of-combat drag target in HUD Layout Mode.
    self.mover:SetHidden(false)
    self.mover:SetMouseEnabled(true)
    self.mover:SetMovable(true)

    local hasSynergy = self:NativeHasSynergy()
    if hasSynergy then
        self.previewing = false
        local synergy = self:GetNativeSynergy()
        if synergy and synergy.control and type(synergy.control.SetHidden) == "function" then
            -- UI/cursor mode may suppress HUD shared-information controls even
            -- while a real synergy is active; keep the real stock prompt visible
            -- during layout mode without changing its logical availability.
            synergy.control:SetHidden(false)
        end
    else
        self:ShowNativeLayoutPreview()
    end

    self:SyncMoverDimensions()
    if not self.dragging then self:AnchorMoverToCurrentPosition() end
    self:AnchorNativeToMover()
end

function S:SetLayoutMode(active)
    self.layoutMode = active == true
    self:CreateMover()

    if self.layoutMode then
        self:RefreshLayoutMover()
    else
        self.dragging = false
        self:RefreshLayoutMover()
        if not self:ApplySavedAnchor() then self:RestoreNativeAnchor() end
        self:RestoreNativeVisibilityState()
        -- OnSynergyAbilityChanged does not own positioning, but reapply once more
        -- in case another style callback happened while layout mode was closing.
        if not self:ApplySavedAnchor() then self:RestoreNativeAnchor() end

        -- HUD Layout Mode also toggles camera UI mode. Run one guarded cleanup
        -- after that transition finishes so the preview cannot remain stuck on
        -- screen. If a real synergy becomes available meanwhile, the cleanup
        -- detects it and leaves ESO's live prompt alone.
        if type(zo_callLater) == "function" then
            zo_callLater(function()
                local overlay = EPC.SynergyOverlay
                if overlay and not overlay.layoutMode then
                    overlay:RestoreNativeVisibilityState()
                    if not overlay:ApplySavedAnchor() then overlay:RestoreNativeAnchor() end
                end
            end, 50)
        end
    end
end

function S:ResetPosition()
    if not EPC.saved then return end
    EPC.saved.synergyOverlayCustom2861 = false
    EPC.saved.synergyOverlayOffsetX2861 = 0
    EPC.saved.synergyOverlayOffsetY2861 = 0

    self:RestoreNativeAnchor()
    if self.layoutMode then
        self:AnchorMoverToCurrentPosition()
        self:RefreshLayoutMover()
    end
end

function S:HookNativeAnchor()
    local synergy = self:GetNativeSynergy()
    if not synergy then return false end
    if self.hooked2863 then
        if self.layoutMode then
            self:RefreshLayoutMover()
        else
            self:ApplySavedAnchor()
        end
        return true
    end

    if type(SecurePostHook) == "function" then
        if type(synergy.ApplyTextStyle) == "function" then
            SecurePostHook(synergy, "ApplyTextStyle", function()
                local overlay = EPC.SynergyOverlay
                if not overlay then return end
                if overlay.layoutMode then
                    overlay:RefreshLayoutMover()
                else
                    overlay:ApplySavedAnchor()
                end
            end)
        end

        if type(synergy.OnSynergyAbilityChanged) == "function" then
            SecurePostHook(synergy, "OnSynergyAbilityChanged", function()
                local overlay = EPC.SynergyOverlay
                if overlay and overlay.layoutMode then overlay:RefreshLayoutMover() end
            end)
        end
    end

    self.hooked2863 = true
    if self.layoutMode then
        self:RefreshLayoutMover()
    else
        self:ApplySavedAnchor()
    end
    return true
end

function S:Initialize()
    self.layoutMode = false
    self.dragging = false
    self.previewing = false
    self:CreateMover()
    self:HookNativeAnchor()

    local prefix = (EPC.name or "EAS") .. "_SynergyOverlay2863"
    if EVENT_PLAYER_ACTIVATED then
        EPC.Runtime:RegisterEvent("SynergyOverlay","Activated",EVENT_PLAYER_ACTIVATED, function()
            self:HookNativeAnchor()
            if self.layoutMode then
                self:RefreshLayoutMover()
            else
                self:ApplySavedAnchor()
            end
        end)
    end
end


-- BEGIN ABSORBED: SynergyTextVisibilityFix.lua
-- ESO Adventurer Suite
-- v0.29.511 - restore native synergy action text when the icon/key remain visible.
-- ESO only refreshes the action label when the synergy name changes; this
-- additive fix reasserts the current native prompt without replacing ESO handlers.

local EPC = ESOProgressionCoach
if not EPC then return end

EPC.SynergyTextVisibilityFix = EPC.SynergyTextVisibilityFix or {}
local F = EPC.SynergyTextVisibilityFix

local EVENT_PREFIX = (EPC.name or "ESOAdventurerSuite") .. "_SynergyText029511"

local function BuildCurrentPrompt()
    if type(GetCurrentSynergyInfo) ~= "function" then return false, "" end

    local ok, hasSynergy, synergyName, _, prompt = pcall(GetCurrentSynergyInfo)
    if not ok or hasSynergy ~= true then return false, "" end

    prompt = tostring(prompt or "")
    synergyName = tostring(synergyName or "")

    if prompt == "" and synergyName ~= "" then
        if rawget(_G, "SI_USE_SYNERGY") and type(zo_strformat) == "function" then
            local formatOk, formatted = pcall(zo_strformat, SI_USE_SYNERGY, synergyName)
            if formatOk and type(formatted) == "string" and formatted ~= "" then
                prompt = formatted
            end
        end
        if prompt == "" then prompt = synergyName end
    end

    return true, prompt
end

function F:RestoreLiveText()
    local synergy = rawget(_G, "SYNERGY")
    if type(synergy) ~= "table" or not synergy.action then return false end

    local hasSynergy, prompt = BuildCurrentPrompt()
    if not hasSynergy then return false end

    local action = synergy.action
    if prompt ~= "" and type(action.SetText) == "function" then
        pcall(action.SetText, action, prompt)
    end
    if type(action.SetHidden) == "function" then
        pcall(action.SetHidden, action, false)
    end
    if type(action.SetAlpha) == "function" then
        pcall(action.SetAlpha, action, 1)
    end

    -- Keep ESO's own stock prompt control visible. Do not touch shared-information
    -- logical availability; only repair the visual label when a real synergy exists.
    if synergy.control and type(synergy.control.SetHidden) == "function" then
        pcall(synergy.control.SetHidden, synergy.control, false)
    end

    return true
end

function F:InstallHook()
    local synergy = rawget(_G, "SYNERGY")
    if type(synergy) ~= "table" then return false end
    if self.hooked then return true end

    if type(SecurePostHook) == "function" and type(synergy.OnSynergyAbilityChanged) == "function" then
        SecurePostHook(synergy, "OnSynergyAbilityChanged", function()
            local fix = EPC.SynergyTextVisibilityFix
            if fix then fix:RestoreLiveText() end
        end)
    end

    self.hooked = true
    self:RestoreLiveText()
    return true
end

local function RefreshAfterEvent()
    F:InstallHook()
    F:RestoreLiveText()
    if type(zo_callLater) == "function" then
        -- Some UI/scene state changes finish just after the native event.
        zo_callLater(function() F:RestoreLiveText() end, 25)
        zo_callLater(function() F:RestoreLiveText() end, 100)
    end
end

if EVENT_SYNERGY_ABILITY_CHANGED then
    EPC.Runtime:RegisterEvent("SynergyTextVisibility","Changed",EVENT_SYNERGY_ABILITY_CHANGED, RefreshAfterEvent)
end
if EVENT_PLAYER_ACTIVATED then
    EPC.Runtime:RegisterEvent("SynergyTextVisibility","Activated",EVENT_PLAYER_ACTIVATED, RefreshAfterEvent)
end

if type(zo_callLater) == "function" then
    zo_callLater(RefreshAfterEvent, 500)
    zo_callLater(RefreshAfterEvent, 1500)
else
    RefreshAfterEvent()
end

-- END ABSORBED: SynergyTextVisibilityFix.lua
