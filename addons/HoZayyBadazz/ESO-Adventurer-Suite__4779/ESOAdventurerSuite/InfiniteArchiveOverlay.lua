-- ESO Adventurer Suite
-- Copyright (c) 2026 HoZayyBadazz. All Rights Reserved.
-- Proprietary source. Unauthorized redistribution, republication, rebranding,
-- or public distribution of modified/derivative versions is prohibited.
-- Private personal-use modifications are permitted. See LICENSE.txt.
--
-- Suite-managed Infinite Archive HUD tracker.
--
-- ESO owns the live Infinite Archive tracker and can hide/re-anchor it as HUD
-- scenes change.  The Suite keeps the live tracker for gameplay (so the real
-- keybind and progression behavior stay intact), but uses a Suite-owned layout
-- preview while HUD Layout Mode is active.  That preview is independent of the
-- HUD scene, so it remains visible and draggable above LibAddonMenu settings.

local EPC = ESOProgressionCoach
EPC.InfiniteArchiveOverlay = EPC.InfiniteArchiveOverlay or {}
local A = EPC.InfiniteArchiveOverlay
local wm = WINDOW_MANAGER

local REASON_DISABLED = "EAS_InfiniteArchiveOverlayDisabled"
local REASON_LAYOUT = "EAS_InfiniteArchiveOverlayLayoutPreview"

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if not ok then return fallback end
    return a, b, c, d, e
end

local function raiseControl(control)
    if not control then return end
    pcall(function()
        if control.SetTopLevel then control:SetTopLevel(true) end
        if control.SetDrawTier and DT_HIGH then control:SetDrawTier(DT_HIGH) end
        if control.SetDrawLayer and DL_OVERLAY then control:SetDrawLayer(DL_OVERLAY) end
        if control.SetDrawLevel then control:SetDrawLevel(1000) end
    end)
end

function A:GetNativeTracker()
    local tracker = rawget(_G, "ENDLESS_DUNGEON_HUD_TRACKER")
    local control = rawget(_G, "ZO_EndDunHUDTracker")
    if tracker and tracker.control then control = tracker.control end
    return tracker, control
end

function A:GetNativeFragment()
    local tracker = self:GetNativeTracker()
    local fragment = rawget(_G, "ENDLESS_DUNGEON_HUD_TRACKER_FRAGMENT")
    if not fragment and tracker and type(tracker.GetFragment) == "function" then
        fragment = safe(tracker.GetFragment, nil, tracker)
    end
    return fragment
end

function A:SetNativeHiddenForReason(reason, hidden)
    local fragment = self:GetNativeFragment()
    if fragment and type(fragment.SetHiddenForReason) == "function" then
        fragment:SetHiddenForReason(reason, hidden == true)
    end
end

function A:IsArchiveStarted()
    local manager = rawget(_G, "ENDLESS_DUNGEON_MANAGER")
    if manager and type(manager.IsEndlessDungeonStarted) == "function" then
        return safe(manager.IsEndlessDungeonStarted, false, manager) == true
    end
    if type(IsEndlessDungeonStarted) == "function" then
        return safe(IsEndlessDungeonStarted, false) == true
    end
    return false
end

function A:GetPosition()
    local left = tonumber(EPC.saved and EPC.saved.infiniteArchiveOverlayLeft) or -1
    local top = tonumber(EPC.saved and EPC.saved.infiniteArchiveOverlayTop) or -1
    return left, top
end

function A:GetScale()
    local scale = tonumber(EPC.saved and EPC.saved.infiniteArchiveOverlayScale) or 1.0
    return math.max(0.65, math.min(1.80, scale))
end

local ApplyPositionImplArch

function A:ApplyPosition(...)

    return ApplyPositionImplArch(self, ...)

end

ApplyPositionImplArch = function(self)
    local _, control = self:GetNativeTracker()
    if not control then return end

    control:SetScale(self:GetScale())
    if control.SetClampedToScreen then control:SetClampedToScreen(true) end

    local left, top = self:GetPosition()
    if left >= 0 and top >= 0 then
        control:ClearAnchors()
        control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
    end
end

function A:GetPreviewTitle()
    if SI_ENDLESS_DUNGEON_HUD_TRACKER_TITLE and type(GetString) == "function" then
        local text = safe(GetString, "", SI_ENDLESS_DUNGEON_HUD_TRACKER_TITLE)
        if text and text ~= "" then return text end
    end
    return "Infinite Archive"
end

function A:GetPreviewProgress()
    local manager = rawget(_G, "ENDLESS_DUNGEON_MANAGER")
    if manager and self:IsArchiveStarted() and type(manager.GetCurrentProgressionText) == "function" then
        local text = safe(manager.GetCurrentProgressionText, "", manager, true)
        if text and text ~= "" then return text end
    end

    local managerClass = rawget(_G, "ZO_EndlessDungeonManager")
    if managerClass and type(managerClass.GetProgressionText) == "function" then
        local text = safe(managerClass.GetProgressionText, "", 1, 1, 1, true)
        if text and text ~= "" then return text end
    end
    return "Arc 1   Cycle 1   Stage 1"
end

local GetKeybindTextImplArch

function A:GetKeybindText(...)

    return GetKeybindTextImplArch(self, ...)

end

GetKeybindTextImplArch = function(self)
    if type(GetActionBindingInfo) == "function" then
        local keyCode = safe(GetActionBindingInfo, nil, "TOGGLE_ACTIVITY_HUD_TRACKER", 1)
        if keyCode and keyCode ~= KEY_INVALID and type(GetKeyName) == "function" then
            local keyName = safe(GetKeyName, "", keyCode)
            if keyName and keyName ~= "" then return keyName end
        end
    end
    return "F5"
end

function A:CreateLayoutPreview()
    if self.previewFrame then return self.previewFrame end

    local frame = wm:CreateTopLevelWindow("EAS_InfiniteArchiveOverlayPreview")
    frame:SetDimensions(250, 76)
    frame:SetClampedToScreen(true)
    frame:SetMouseEnabled(false)
    frame:SetMovable(false)
    frame:SetHidden(true)

    local keyBg = wm:CreateControl("EAS_InfiniteArchiveOverlayPreview_KeyBG", frame, CT_BACKDROP)
    keyBg:SetAnchor(TOPLEFT, frame, TOPLEFT, 0, 4)
    keyBg:SetDimensions(46, 32)
    keyBg:SetCenterColor(0.02, 0.025, 0.03, 0.92)
    keyBg:SetEdgeColor(0.94, 0.96, 0.96, 1)
    keyBg:SetEdgeTexture(nil, 2, 2, 2)

    local key = wm:CreateControl("EAS_InfiniteArchiveOverlayPreview_Key", keyBg, CT_LABEL)
    key:SetAnchorFill(keyBg)
    key:SetFont("ZoFontGameBold")
    key:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    key:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    key:SetColor(1, 1, 1, 1)

    local title = wm:CreateControl("EAS_InfiniteArchiveOverlayPreview_Title", frame, CT_LABEL)
    title:SetAnchor(TOPLEFT, keyBg, TOPRIGHT, 10, 0)
    title:SetDimensions(190, 28)
    title:SetFont("ZoFontGameShadow")
    title:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    title:SetColor(0.94, 0.88, 0.70, 1)

    local progress = wm:CreateControl("EAS_InfiniteArchiveOverlayPreview_Progress", frame, CT_LABEL)
    progress:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 8, -1)
    progress:SetDimensions(185, 28)
    progress:SetFont("ZoFontGameShadow")
    progress:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    progress:SetColor(1, 1, 1, 1)

    local hint = wm:CreateControl("EAS_InfiniteArchiveOverlayPreview_Hint", frame, CT_LABEL)
    hint:SetAnchor(TOPLEFT, frame, BOTTOMLEFT, 0, -4)
    hint:SetDimensions(250, 20)
    hint:SetFont("ZoFontGameSmall")
    hint:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    hint:SetColor(0.95, 0.82, 0.42, 1)
    hint:SetText("DRAG TO MOVE - INFINITE ARCHIVE")

    frame:SetHandler("OnMoveStart", function()
        A.previewDragging = true
    end)

    frame:SetHandler("OnMoveStop", function(control)
        if not A.layoutMode then
            A.previewDragging = false
            return
        end
        if EPC.saved then
            EPC.saved.infiniteArchiveOverlayLeft = control:GetLeft()
            EPC.saved.infiniteArchiveOverlayTop = control:GetTop()
        end
        A.previewDragging = false
        A:ApplyPosition()
        -- Do not clear/reapply the preview anchor here. The control is already
        -- exactly where the player dropped it, and re-anchoring can make the
        -- drag feel like it snapped or resisted the mouse.
    end)

    self.previewFrame = frame
    self.previewKey = key
    self.previewTitle = title
    self.previewProgress = progress
    self.previewHint = hint

    self:ApplyPreviewPosition()
    return frame
end

function A:ApplyPreviewPosition()
    if not self.previewFrame then return end

    local frame = self.previewFrame
    frame:SetScale(self:GetScale())
    frame:ClearAnchors()

    local left, top = self:GetPosition()
    if left >= 0 and top >= 0 then
        frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
    else
        -- Mirror ESO's default keyboard placement closely enough that moving the
        -- preview feels natural before the player has saved a custom position.
        frame:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -18, 90)
    end
end

function A:RefreshPreviewText()
    if not self.previewFrame then return end
    self.previewKey:SetText(self:GetKeybindText())
    self.previewTitle:SetText(self:GetPreviewTitle())
    self.previewProgress:SetText(self:GetPreviewProgress())
end

function A:RaiseForLayout()
    self:CreateLayoutPreview()
    raiseControl(self.previewFrame)
end

function A:InstallAnchorHook()
    local tracker = self:GetNativeTracker()
    if not tracker or self.anchorHookInstalled then return end
    if type(ZO_PostHook) == "function" and type(tracker.RefreshAnchors) == "function" then
        ZO_PostHook(tracker, "RefreshAnchors", function()
            if EPC.InfiniteArchiveOverlay and not EPC.InfiniteArchiveOverlay.layoutMode then
                EPC.InfiniteArchiveOverlay:ApplyPosition()
            end
        end)
        self.anchorHookInstalled = true
    end
end

function A:RestoreNativeProgress()
    local tracker = self:GetNativeTracker()
    if tracker and type(tracker.UpdateProgress) == "function" then
        pcall(tracker.UpdateProgress, tracker)
    end
end

local RefreshImplArch

function A:Refresh(...)

    return RefreshImplArch(self, ...)

end

RefreshImplArch = function(self)
    local tracker, control = self:GetNativeTracker()

    self:CreateLayoutPreview()
    -- ESO and the Suite both refresh this module frequently. While HUD layout
    -- mode is active, never clear/reapply the preview anchor: doing so during
    -- a drag makes the overlay fight the cursor. We only keep its scale/text
    -- current until the player locks it again.
    if self.layoutMode then
        self.previewFrame:SetScale(self:GetScale())
    else
        self:ApplyPreviewPosition()
    end
    self:RefreshPreviewText()

    local enabled = EPC.saved and EPC.saved.showInfiniteArchiveOverlay ~= false

    if tracker and control then
        self:InstallAnchorHook()
        self:ApplyPosition()

        -- Never make the native ZOS tracker movable directly.  ZOS owns its
        -- scene state and can hide/re-parent it while Settings are open.  The
        -- Suite preview is the stable drag target instead.
        control:SetMouseEnabled(false)
        control:SetMovable(false)

        self:SetNativeHiddenForReason(REASON_DISABLED, not enabled)
        self:SetNativeHiddenForReason(REASON_LAYOUT, self.layoutMode == true)

        if not self.layoutMode then
            self:RestoreNativeProgress()
            if tracker.Update then pcall(tracker.Update, tracker) end
            self:ApplyPosition()
        end
    end

    if self.layoutMode then
        self.previewFrame:SetMouseEnabled(true)
        self.previewFrame:SetMovable(true)
        self.previewFrame:SetHidden(false)
        self:RaiseForLayout()
    else
        self.previewFrame:SetMouseEnabled(false)
        self.previewFrame:SetMovable(false)
        self.previewFrame:SetHidden(true)
    end

    return true
end

function A:SetLayoutMode(active)
    active = active == true
    local entering = active and not self.layoutMode
    self.layoutMode = active
    self.previewDragging = false

    -- Apply the saved position once when move mode begins. After this point the
    -- preview is left completely alone so dragging stays smooth.
    if entering then
        self:CreateLayoutPreview()
        self:ApplyPreviewPosition()
    end
    self:Refresh()
end

local ResetPositionImplArch

function A:ResetPosition(...)

    return ResetPositionImplArch(self, ...)

end

ResetPositionImplArch = function(self)
    if EPC.saved then
        EPC.saved.infiniteArchiveOverlayLeft = -1
        EPC.saved.infiniteArchiveOverlayTop = -1
    end

    local tracker = self:GetNativeTracker()
    if tracker and type(tracker.RefreshAnchors) == "function" then
        pcall(tracker.RefreshAnchors, tracker)
    end
    self:ApplyPreviewPosition()
    self:Refresh()
end

local InitializeImplArch

function A:Initialize(...)

    return InitializeImplArch(self, ...)

end

InitializeImplArch = function(self)
    self.layoutMode = false
    self:CreateLayoutPreview()

    local prefix = (EPC.name or "ESOAdventurerSuite") .. "_InfiniteArchiveOverlay"

    if EVENT_PLAYER_ACTIVATED then
        EVENT_MANAGER:RegisterForEvent(prefix .. "_Activated", EVENT_PLAYER_ACTIVATED, function()
            A:Refresh()
        end)
    end

    local manager = rawget(_G, "ENDLESS_DUNGEON_MANAGER")
    if manager and type(manager.RegisterCallback) == "function" then
        manager:RegisterCallback("StateChanged", function() A:Refresh() end)
        manager:RegisterCallback("DungeonInitialized", function() A:Refresh() end)
        manager:RegisterCallback("DungeonStarted", function() A:Refresh() end)
        manager:RegisterCallback("DungeonCompleted", function() A:Refresh() end)
        manager:RegisterCallback("ProgressionChanged", function() A:Refresh() end)
    end

    -- ZO_Ingame can finish deferred initialization after this addon.  Keep the
    -- native position synchronized and keep the Suite preview above settings
    -- while layout mode is active.
    EVENT_MANAGER:RegisterForUpdate(prefix .. "_Guard", 1000, function()
        -- Event callbacks own normal updates. The safety guard only wakes when
        -- the archive HUD is relevant or being edited.
        if A.layoutMode == true or (A.IsPlayerInArchive02972 and A:IsPlayerInArchive02972())
            or (A.frame and not A.frame:IsHidden()) then
            A:Refresh()
        end
    end)

    self:Refresh()
end

-- ============================================================================
-- v0.29.72 - Suite-owned live Infinite Archive overlay.
-- ESO's native Endless Dungeon fragment may be hidden/reparented by its own HUD
-- state. Keep a Suite-owned tracker visible whenever the player is actually in
-- Infinite Archive, while retaining the same frame as the HUD-layout drag target.
-- ============================================================================
local REASON_SUITE_LIVE_02972 = "EAS_InfiniteArchiveSuiteLive02972"

function A:IsPlayerInArchive02972()
    local manager = rawget(_G, "ENDLESS_DUNGEON_MANAGER")
    if manager and type(manager.IsPlayerInEndlessDungeon) == "function" then
        if safe(manager.IsPlayerInEndlessDungeon, false, manager) == true then return true end
    end
    return self:IsArchiveStarted() == true
end

GetKeybindTextImplArch = function(self)
    if type(GetHighestPriorityActionBindingInfoFromName) == "function" then
        local keyCode = safe(GetHighestPriorityActionBindingInfoFromName, nil, "TOGGLE_ACTIVITY_HUD_TRACKER", false)
        if keyCode and keyCode ~= KEY_INVALID and type(GetKeyName) == "function" then
            local keyName = safe(GetKeyName, "", keyCode)
            if keyName and keyName ~= "" then return keyName end
        end
    end
    return "F5"
end

local EAS_InfiniteRefreshBase02972 = RefreshImplArch
RefreshImplArch = function(self)
    EAS_InfiniteRefreshBase02972(self)

    self:CreateLayoutPreview()
    self:RefreshPreviewText()
    local enabled = EPC.saved and EPC.saved.showInfiniteArchiveOverlay ~= false
    local inArchive = self:IsPlayerInArchive02972()
    local showLive = enabled and inArchive and self.layoutMode ~= true

    self:SetNativeHiddenForReason(REASON_SUITE_LIVE_02972, showLive)

    if self.previewFrame then
        if self.layoutMode then
            self.previewFrame:SetMouseEnabled(true)
            self.previewFrame:SetMovable(true)
            self.previewFrame:SetHidden(false)
            if self.previewHint then self.previewHint:SetHidden(false) end
            self:RaiseForLayout()
        elseif showLive then
            self.previewFrame:SetMouseEnabled(false)
            self.previewFrame:SetMovable(false)
            if self.previewHint then self.previewHint:SetHidden(true) end
            self.previewFrame:SetHidden(false)
            raiseControl(self.previewFrame)
        else
            self.previewFrame:SetMouseEnabled(false)
            self.previewFrame:SetMovable(false)
            if self.previewHint then self.previewHint:SetHidden(true) end
            self.previewFrame:SetHidden(true)
        end
    end
    return true
end

-- ============================================================================
-- v0.29.74 - isolate Suite Archive HUD from ESO's native objective tracker
-- The native Endless Dungeon tracker participates in ZOS' objective-tracker
-- layout. Re-anchoring it from HUD Layout Mode can therefore disturb the native
-- quest tracker. From this version onward the Suite never moves/re-anchors the
-- native tracker; its own preview/live frame is the only movable Archive HUD.
-- ============================================================================
local REASON_NATIVE_ISOLATION_02974 = "EAS_InfiniteArchiveNativeIsolation02974"

ApplyPositionImplArch = function(self)
    -- Compatibility no-op for the native tracker. Older callers still invoke
    -- ApplyPosition(), but only the Suite-owned frame is allowed to move now.
    if self.previewFrame and not self.previewDragging then
        self:ApplyPreviewPosition()
    end
end

ResetPositionImplArch = function(self)
    if EPC.saved then
        EPC.saved.infiniteArchiveOverlayLeft = -1
        EPC.saved.infiniteArchiveOverlayTop = -1
    end
    self:CreateLayoutPreview()
    self:ApplyPreviewPosition()
    self:Refresh()
end

RefreshImplArch = function(self)
    self:CreateLayoutPreview()

    if self.layoutMode then
        if self.previewFrame then self.previewFrame:SetScale(self:GetScale()) end
    elseif not self.previewDragging then
        self:ApplyPreviewPosition()
    end
    self:RefreshPreviewText()

    local enabled = EPC.saved and EPC.saved.showInfiniteArchiveOverlay ~= false
    local inArchive = self:IsPlayerInArchive02972()
    local showLive = enabled and inArchive and self.layoutMode ~= true

    -- The Suite owns the visible Archive HUD. The ZOS tracker remains hidden
    -- while our live tracker is shown, but we never alter its anchors, scale,
    -- mouse state, parent, or update layout.
    self:SetNativeHiddenForReason(REASON_DISABLED, not enabled)
    self:SetNativeHiddenForReason(REASON_LAYOUT, self.layoutMode == true)
    self:SetNativeHiddenForReason(REASON_SUITE_LIVE_02972, showLive)
    self:SetNativeHiddenForReason(REASON_NATIVE_ISOLATION_02974, enabled and (showLive or self.layoutMode == true))

    if not self.previewFrame then return true end

    if self.layoutMode then
        self.previewFrame:SetMouseEnabled(true)
        self.previewFrame:SetMovable(true)
        self.previewFrame:SetHidden(false)
        if self.previewHint then self.previewHint:SetHidden(false) end
        self:RaiseForLayout()
    elseif showLive then
        self.previewFrame:SetMouseEnabled(false)
        self.previewFrame:SetMovable(false)
        self.previewFrame:SetHidden(false)
        if self.previewHint then self.previewHint:SetHidden(true) end
        raiseControl(self.previewFrame)
    else
        self.previewFrame:SetMouseEnabled(false)
        self.previewFrame:SetMovable(false)
        self.previewFrame:SetHidden(true)
        if self.previewHint then self.previewHint:SetHidden(true) end
    end
    return true
end

-- ============================================================================
-- v0.29.75 - gameplay-only Infinite Archive visibility.
-- The Suite Archive tracker is a HUD element, not a menu element. Hide it as
-- soon as ESO enters Pause, Map, Inventory, Settings, or another UI/menu scene.
-- HUD Layout Mode remains a gameplay preview and is allowed only while no real
-- ESO menu scene is suppressing the HUD.
-- ============================================================================
function A:IsArchiveHudVisible02975()
    if EPC and type(EPC.IsGameplayHudSuppressed) == "function" then
        local ok, suppressed = pcall(EPC.IsGameplayHudSuppressed, EPC)
        if ok then return suppressed ~= true end
    end

    -- Conservative fallback for installations where Core's helper has not yet
    -- initialized: ordinary camera UI mode means a menu/UI is owning the screen.
    -- HUD Layout Mode is the one intentional exception.
    if self.layoutMode ~= true and type(IsGameCameraUIModeActive) == "function" then
        local ok, active = pcall(IsGameCameraUIModeActive)
        if ok and active == true then return false end
    end
    return true
end

RefreshImplArch = function(self)
    self:CreateLayoutPreview()

    if self.layoutMode then
        if self.previewFrame then self.previewFrame:SetScale(self:GetScale()) end
    elseif not self.previewDragging then
        self:ApplyPreviewPosition()
    end
    self:RefreshPreviewText()

    local enabled = EPC.saved and EPC.saved.showInfiniteArchiveOverlay ~= false
    local inArchive = self:IsPlayerInArchive02972()
    local hudVisible = self:IsArchiveHudVisible02975()
    local showLive = enabled and inArchive and self.layoutMode ~= true and hudVisible
    local showLayout = self.layoutMode == true and hudVisible

    -- Keep the ZOS activity/objective tracker isolated while the Suite owns the
    -- Archive display. Never alter the native tracker's anchors or position.
    self:SetNativeHiddenForReason(REASON_DISABLED, not enabled)
    self:SetNativeHiddenForReason(REASON_LAYOUT, self.layoutMode == true)
    self:SetNativeHiddenForReason(REASON_SUITE_LIVE_02972, showLive)
    self:SetNativeHiddenForReason(REASON_NATIVE_ISOLATION_02974, enabled and (showLive or showLayout))

    if not self.previewFrame then return true end

    if showLayout then
        self.previewFrame:SetMouseEnabled(true)
        self.previewFrame:SetMovable(true)
        self.previewFrame:SetHidden(false)
        if self.previewHint then self.previewHint:SetHidden(false) end
        self:RaiseForLayout()
    elseif showLive then
        self.previewFrame:SetMouseEnabled(false)
        self.previewFrame:SetMovable(false)
        self.previewFrame:SetHidden(false)
        if self.previewHint then self.previewHint:SetHidden(true) end
        raiseControl(self.previewFrame)
    else
        self.previewFrame:SetMouseEnabled(false)
        self.previewFrame:SetMovable(false)
        self.previewFrame:SetHidden(true)
        if self.previewHint then self.previewHint:SetHidden(true) end
    end
    return true
end



-- ============================================================================
-- v0.29.78 - permanently suppress ESO's native Infinite Archive tracker.
-- The Suite now owns the Archive HUD completely.  The ZOS Endless Dungeon HUD
-- fragment must never become visible again during focus loss, menus, scene
-- transitions, or while the Suite-owned Archive frame is intentionally hidden.
-- ============================================================================
local REASON_NATIVE_ALWAYS_02978 = "EAS_InfiniteArchiveNativeAlwaysHidden02978"

function A:SuppressNativeTracker02978()
    -- Prefer the fragment hidden-for-reason API because it survives normal
    -- scene transitions without touching the native tracker's anchors.
    self:SetNativeHiddenForReason(REASON_NATIVE_ALWAYS_02978, true)

    -- Defensive fallback for clients/builds where the fragment has not been
    -- initialized yet or is temporarily unavailable. The 250 ms guard calls
    -- Refresh repeatedly, so this will be reasserted as soon as the control
    -- exists. Do not change its anchors/scale/parent.
    local _, control = self:GetNativeTracker()
    local fragment = self:GetNativeFragment()
    if control and not fragment and type(control.SetHidden) == "function" then
        pcall(control.SetHidden, control, true)
    end
end

local EAS_InfiniteRefreshBase02978 = RefreshImplArch
RefreshImplArch = function(self)
    -- Suppress the native tracker before doing any Suite visibility work. This
    -- remains true even if the Suite frame hides because the game loses focus,
    -- a menu opens, or the user disables the Suite Archive overlay.
    self:SuppressNativeTracker02978()
    local result = EAS_InfiniteRefreshBase02978(self)
    -- Reassert after the base refresh as older compatibility reasons may be
    -- toggled there. The dedicated 0.29.78 reason is never released.
    self:SuppressNativeTracker02978()
    return result
end

-- ============================================================================
-- v0.29.171 - Infinite Archive Verse / Vision Choice Advisor.
-- Guidance only: the Suite never chooses or rerolls a buff for the player.
-- ESO's selector exposes each offered abilityId; the Suite scores those choices
-- against the current build role, Archive progression, remaining attempts and
-- the Verses/Visions already active in this run, then highlights the best pick.
-- ============================================================================

local function EAS_IA_Normalize029171(value)
    local text = string.lower(tostring(value or ""))
    text = text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("[^%w%s%%'%-]", " ")
    text = text:gsub("%s+", " ")
    return text:gsub("^%s+", ""):gsub("%s+$", "")
end

local function EAS_IA_Has029171(text, words)
    text = EAS_IA_Normalize029171(text)
    for _, word in ipairs(words or {}) do
        if text:find(EAS_IA_Normalize029171(word), 1, true) then return true end
    end
    return false
end

local function EAS_IA_First029171(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d
end

function A:GetChoiceAdvisorRole029171()
    if EPC and EPC.RotationAssistant and type(EPC.RotationAssistant.GetAdvisorRole029161) == "function" then
        local ok, role = pcall(EPC.RotationAssistant.GetAdvisorRole029161, EPC.RotationAssistant)
        if ok and role then return tostring(role) end
    end

    local magickaMax, staminaMax = 0, 0
    if type(GetUnitPower) == "function" then
        local okM, _, maxM = pcall(GetUnitPower, "player", POWERTYPE_MAGICKA)
        local okS, _, maxS = pcall(GetUnitPower, "player", POWERTYPE_STAMINA)
        if okM then magickaMax = tonumber(maxM) or 0 end
        if okS then staminaMax = tonumber(maxS) or 0 end
    end
    if magickaMax > staminaMax * 1.12 then return "MAGICKA_DPS" end
    if staminaMax > magickaMax * 1.12 then return "STAMINA_DPS" end
    return "HYBRID"
end

function A:GetArchiveRunContext029171()
    local context = { stage = 1, cycle = 1, arc = 1, attempts = 3, role = self:GetChoiceAdvisorRole029171() }
    local manager = rawget(_G, "ENDLESS_DUNGEON_MANAGER")
    if manager and type(manager.GetProgression) == "function" then
        local ok, stage, cycle, arc = pcall(manager.GetProgression, manager)
        if ok then
            context.stage = math.max(1, tonumber(stage) or 1)
            context.cycle = math.max(1, tonumber(cycle) or 1)
            context.arc = math.max(1, tonumber(arc) or 1)
        end
    end
    if manager and type(manager.GetAttemptsRemaining) == "function" then
        context.attempts = math.max(0, tonumber(EAS_IA_First029171(manager.GetAttemptsRemaining, manager)) or 3)
    end
    return context
end

local EAS_IA_TAGS_029171 = {
    OFFENSE = {"damage", "critical", "penetration", "weapon and spell damage", "weapon damage", "spell damage", "offensive penetration", "critical damage"},
    DIRECT = {"direct damage", "light attack", "heavy attack"},
    DOT = {"damage over time", "every second", "every 1 second", "bleed", "burning", "poisoned"},
    STATUS = {"status effect", "burning", "concussed", "chilled", "poisoned", "diseased", "hemorrhaging", "sundered", "overcharged"},
    MAGICKA = {"magicka", "magic damage", "flame damage", "frost damage", "shock damage", "spell"},
    STAMINA = {"stamina", "physical damage", "bleed damage", "poison damage", "disease damage", "weapon"},
    SURVIVAL = {"damage taken", "damage reduction", "resistance", "armor", "max health", "health", "shield", "block", "mitigation", "protection"},
    HEALING = {"healing done", "healing received", "restore health", "heal", "healing"},
    SUSTAIN = {"recovery", "restore magicka", "restore stamina", "cost reduction", "reduces the cost", "resource", "magicka cost", "stamina cost"},
    ULTIMATE = {"ultimate", "ultimate generation", "ultimate cost"},
    SPEED = {"movement speed", "sprint", "speed"},
    PET = {"pet", "companion", "summoned", "familiar", "bear"},
}

function A:GetArchiveChoiceText029171(abilityId)
    abilityId = tonumber(abilityId) or 0
    if abilityId <= 0 then return "", "" end
    local name = tostring(EAS_IA_First029171(GetAbilityName, abilityId) or "")
    local description = ""
    if type(GetAbilityDescription) == "function" then
        description = tostring(EAS_IA_First029171(GetAbilityDescription, abilityId) or "")
    end
    return name, EAS_IA_Normalize029171(name .. " " .. description)
end

function A:GetArchiveChoiceTags029171(text)
    local tags = {}
    for tag, words in pairs(EAS_IA_TAGS_029171) do
        if EAS_IA_Has029171(text, words) then tags[tag] = true end
    end
    return tags
end

function A:GetActiveArchiveSynergy029171()
    local manager = rawget(_G, "ENDLESS_DUNGEON_MANAGER")
    local synergy = { tags = {}, names = {}, count = 0 }
    if not manager or type(manager.GetAbilityStackCountTable) ~= "function" then return synergy end

    local buffTypes = { rawget(_G, "ENDLESS_DUNGEON_BUFF_TYPE_VERSE"), rawget(_G, "ENDLESS_DUNGEON_BUFF_TYPE_VISION") }
    for _, buffType in ipairs(buffTypes) do
        if buffType ~= nil then
            local ok, stackTable = pcall(manager.GetAbilityStackCountTable, manager, buffType)
            if ok and type(stackTable) == "table" then
                for abilityId, stacks in pairs(stackTable) do
                    local name, text = self:GetArchiveChoiceText029171(abilityId)
                    local weight = math.max(1, tonumber(stacks) or 1)
                    synergy.count = synergy.count + weight
                    synergy.names[EAS_IA_Normalize029171(name)] = weight
                    local tags = self:GetArchiveChoiceTags029171(text)
                    for tag in pairs(tags) do synergy.tags[tag] = (synergy.tags[tag] or 0) + weight end
                end
            end
        end
    end
    return synergy
end

function A:ScoreArchiveChoice029171(abilityId, buffType, isAvatarVision, context, synergy)
    local name, text = self:GetArchiveChoiceText029171(abilityId)
    if text == "" then return -9999, "Unknown choice" end
    local tags = self:GetArchiveChoiceTags029171(text)
    local role = tostring(context.role or "HYBRID")
    local score = 100
    local reasons = {}

    local function add(points, reason)
        score = score + points
        if reason and reason ~= "" then reasons[#reasons + 1] = reason end
    end

    -- Avatar Visions are build-defining and intentionally rare. They should be
    -- extremely difficult for an ordinary temporary Verse to beat.
    if isAvatarVision == true then add(520, "Avatar Vision") end

    if role == "TANK" then
        if tags.SURVIVAL then add(330, "tank survival") end
        if tags.SUSTAIN then add(185, "block/sustain") end
        if tags.HEALING then add(165, "self sustain") end
        if tags.OFFENSE then add(95, "damage") end
    elseif role == "HEALER" then
        if tags.HEALING then add(350, "healing") end
        if tags.SUSTAIN then add(220, "sustain") end
        if tags.SURVIVAL then add(145, "survival") end
        if tags.OFFENSE then add(80, "damage") end
    elseif role == "MAGICKA_DPS" then
        if tags.OFFENSE then add(315, "damage") end
        if tags.MAGICKA then add(245, "Magicka synergy") end
        if tags.STATUS or tags.DOT or tags.DIRECT then add(150, "damage synergy") end
        if tags.ULTIMATE then add(130, "Ultimate") end
        if tags.SUSTAIN then add(105, "sustain") end
    elseif role == "STAMINA_DPS" then
        if tags.OFFENSE then add(315, "damage") end
        if tags.STAMINA then add(245, "Stamina synergy") end
        if tags.STATUS or tags.DOT or tags.DIRECT then add(150, "damage synergy") end
        if tags.ULTIMATE then add(130, "Ultimate") end
        if tags.SUSTAIN then add(105, "sustain") end
    else
        if tags.OFFENSE then add(305, "damage") end
        if tags.STATUS or tags.DOT or tags.DIRECT then add(155, "damage synergy") end
        if tags.MAGICKA or tags.STAMINA then add(125, "resource damage") end
        if tags.ULTIMATE then add(125, "Ultimate") end
        if tags.SUSTAIN then add(115, "sustain") end
    end

    -- Archive difficulty rises with Arc. Gradually value survivability more in
    -- deeper runs without suddenly turning a DPS build into a tank in Arc 2.
    local deepRun = math.max(0, (tonumber(context.arc) or 1) - 2)
    if deepRun > 0 and tags.SURVIVAL then add(math.min(210, deepRun * 32), "deep-Arc survival") end
    if deepRun > 1 and tags.HEALING then add(math.min(120, deepRun * 18), "deep-Arc healing") end
    if (tonumber(context.attempts) or 3) <= 1 and tags.SURVIVAL then add(130, "last-thread safety") end

    -- Reinforce a theme the current run has already invested in. This makes the
    -- recommendation genuinely run-aware rather than ranking each choice in a
    -- vacuum. Cap the bonus so a bad role mismatch cannot win only by stacking.
    for tag in pairs(tags) do
        local existing = tonumber(synergy.tags and synergy.tags[tag]) or 0
        if existing > 0 then
            add(math.min(150, 35 + existing * 16), "run synergy")
        end
    end

    local normalizedName = EAS_IA_Normalize029171(name)
    if normalizedName ~= "" and synergy.names and synergy.names[normalizedName] then
        -- Visions often intentionally stack. Existing investment is therefore a
        -- positive signal rather than a reason to reject the same Vision.
        add(math.min(115, 45 + (tonumber(synergy.names[normalizedName]) or 1) * 18), "stack existing choice")
    end

    -- Small universal quality signals.
    if tags.SPEED and not tags.OFFENSE and not tags.SURVIVAL then score = score - 30 end
    if tags.PET and role ~= "HEALER" then add(55, "pet synergy") end

    local reason = reasons[1] or "best overall fit"
    if #reasons >= 2 then reason = reasons[1] .. " + " .. reasons[2] end
    return score, reason
end

local EAS_ARCHIVE_STAR_TEXTURE_029177 = "EsoUI/Art/Miscellaneous/lensflare_star_256.dds"

function A:EnsureArchiveChoiceGlow029171(buffControl)
    if not buffControl or buffControl.easBestGlow029171 then return end

    -- v0.29.173: Keep the per-choice recommendation visuals inside the
    -- selector choice itself, but ONLY within the existing 140x140 icon bounds.
    -- This is safe for ZOS resize-to-fit controls because nothing extends the
    -- measured descendant extents. The native Highlight texture is also marked
    -- excludeFromResizeToFitExtents by ZOS and is the primary recommendation glow.
    local icon = buffControl.iconTexture or (buffControl.GetNamedChild and buffControl:GetNamedChild("Icon"))
    local nativeHighlight = buffControl.highlightTexture or (buffControl.GetNamedChild and buffControl:GetNamedChild("Highlight"))

    local frame = wm:CreateControl(nil, buffControl, CT_BACKDROP)
    if icon then
        frame:SetAnchor(TOPLEFT, icon, TOPLEFT, 0, 0)
        frame:SetAnchor(BOTTOMRIGHT, icon, BOTTOMRIGHT, 0, 0)
    else
        frame:SetAnchorFill(buffControl)
    end
    frame:SetCenterColor(0.12, 0.55, 0.10, 0.08)
    frame:SetEdgeColor(0.35, 1.00, 0.20, 1)
    frame:SetEdgeTexture(nil, 8, 8, 8)
    frame:SetMouseEnabled(false)
    if frame.SetDrawLevel then frame:SetDrawLevel(20) end
    if frame.SetExcludeFromResizeToFitExtents then frame:SetExcludeFromResizeToFitExtents(true) end
    frame:SetHidden(true)

    local badge = wm:CreateControl(nil, buffControl, CT_LABEL)
    if icon then
        badge:SetAnchor(TOP, icon, TOP, 0, 5)
    else
        badge:SetAnchor(TOP, buffControl, TOP, 0, 5)
    end
    badge:SetDimensions(136, 28)
    badge:SetFont("$(BOLD_FONT)|20|soft-shadow-thick")
    badge:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    badge:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    badge:SetColor(0.55, 1.00, 0.30, 1)
    badge:SetText("BEST")
    if badge.SetDrawLevel then badge:SetDrawLevel(22) end
    if badge.SetExcludeFromResizeToFitExtents then badge:SetExcludeFromResizeToFitExtents(true) end
    badge:SetHidden(true)

    -- v0.29.177: Use real ESO textures instead of Unicode star glyphs.
    -- Some ESO fonts render the Unicode star as an empty square. Keeping
    -- these textures inside the icon bounds also preserves resize safety.
    local starLeft = wm:CreateControl(nil, buffControl, CT_TEXTURE)
    starLeft:SetTexture(EAS_ARCHIVE_STAR_TEXTURE_029177)
    starLeft:SetDimensions(20, 20)
    if icon then
        starLeft:SetAnchor(TOPLEFT, icon, TOPLEFT, 8, 8)
    else
        starLeft:SetAnchor(TOPLEFT, buffControl, TOPLEFT, 8, 8)
    end
    if starLeft.SetBlendMode and TEX_BLEND_MODE_ADD then starLeft:SetBlendMode(TEX_BLEND_MODE_ADD) end
    if starLeft.SetColor then starLeft:SetColor(0.65, 1.00, 0.30, 1) end
    if starLeft.SetDrawLevel then starLeft:SetDrawLevel(23) end
    if starLeft.SetExcludeFromResizeToFitExtents then starLeft:SetExcludeFromResizeToFitExtents(true) end
    starLeft:SetHidden(true)

    local starRight = wm:CreateControl(nil, buffControl, CT_TEXTURE)
    starRight:SetTexture(EAS_ARCHIVE_STAR_TEXTURE_029177)
    starRight:SetDimensions(20, 20)
    if icon then
        starRight:SetAnchor(TOPRIGHT, icon, TOPRIGHT, -8, 8)
    else
        starRight:SetAnchor(TOPRIGHT, buffControl, TOPRIGHT, -8, 8)
    end
    if starRight.SetBlendMode and TEX_BLEND_MODE_ADD then starRight:SetBlendMode(TEX_BLEND_MODE_ADD) end
    if starRight.SetColor then starRight:SetColor(0.65, 1.00, 0.30, 1) end
    if starRight.SetDrawLevel then starRight:SetDrawLevel(23) end
    if starRight.SetExcludeFromResizeToFitExtents then starRight:SetExcludeFromResizeToFitExtents(true) end
    starRight:SetHidden(true)

    -- v0.29.341: a cosmetic alpha pulse used to run every rendered frame for
    -- the entire time this choice overlay was visible. Keep the same emphasis
    -- with steady opacity so Infinite Archive does not add a permanent OnUpdate.
    frame:SetHandler("OnUpdate", nil)
    frame:SetAlpha(1)
    badge:SetAlpha(1)
    starLeft:SetAlpha(0.88)
    starRight:SetAlpha(0.88)

    buffControl.easBestGlow029171 = frame
    buffControl.easBestOuter029171 = nil
    buffControl.easBestLabel029171 = badge
    buffControl.easBestStarLeft029177 = starLeft
    buffControl.easBestStarRight029177 = starRight
    buffControl.easBestReason029171 = nil
    buffControl.easBestNativeHighlight029173 = nativeHighlight
end

function A:EnsureArchiveChoiceBanner029173(selector)
    if not selector or not selector.control then return nil end
    if selector.easSuiteChoiceBanner029173 then return selector.easSuiteChoiceBanner029173 end

    local controlName = (selector.control.GetName and selector.control:GetName()) or "ArchiveSelector"
    local root = wm:CreateTopLevelWindow("EAS_ArchiveBestChoiceBanner_" .. tostring(controlName))
    root:SetDimensions(620, 64)
    root:SetAnchor(BOTTOM, selector.control, TOP, 0, -10)
    root:SetMouseEnabled(false)
    root:SetHidden(true)
    if root.SetDrawTier and DT_HIGH then root:SetDrawTier(DT_HIGH) end
    if root.SetDrawLayer and DL_OVERLAY then root:SetDrawLayer(DL_OVERLAY) end
    if root.SetDrawLevel then root:SetDrawLevel(10000) end

    local bg = wm:CreateControl(nil, root, CT_BACKDROP)
    bg:SetAnchorFill(root)
    bg:SetCenterColor(0.01, 0.06, 0.01, 0.92)
    bg:SetEdgeColor(0.35, 1.00, 0.20, 1)
    bg:SetEdgeTexture(nil, 4, 4, 4)
    bg:SetMouseEnabled(false)

    local title = wm:CreateControl(nil, root, CT_LABEL)
    title:SetAnchor(TOPLEFT, root, TOPLEFT, 10, 5)
    title:SetAnchor(TOPRIGHT, root, TOPRIGHT, -10, 5)
    title:SetHeight(28)
    title:SetFont("$(BOLD_FONT)|21|soft-shadow-thick")
    title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    title:SetColor(0.55, 1.00, 0.30, 1)

    local starLeft = wm:CreateControl(nil, root, CT_TEXTURE)
    starLeft:SetTexture(EAS_ARCHIVE_STAR_TEXTURE_029177)
    starLeft:SetDimensions(24, 24)
    starLeft:SetAnchor(LEFT, root, LEFT, 14, -11)
    if starLeft.SetBlendMode and TEX_BLEND_MODE_ADD then starLeft:SetBlendMode(TEX_BLEND_MODE_ADD) end
    if starLeft.SetColor then starLeft:SetColor(0.65, 1.00, 0.30, 1) end

    local starRight = wm:CreateControl(nil, root, CT_TEXTURE)
    starRight:SetTexture(EAS_ARCHIVE_STAR_TEXTURE_029177)
    starRight:SetDimensions(24, 24)
    starRight:SetAnchor(RIGHT, root, RIGHT, -14, -11)
    if starRight.SetBlendMode and TEX_BLEND_MODE_ADD then starRight:SetBlendMode(TEX_BLEND_MODE_ADD) end
    if starRight.SetColor then starRight:SetColor(0.65, 1.00, 0.30, 1) end

    local reason = wm:CreateControl(nil, root, CT_LABEL)
    reason:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 0)
    reason:SetAnchor(TOPRIGHT, title, BOTTOMRIGHT, 0, 0)
    reason:SetHeight(22)
    reason:SetFont("ZoFontGameSmall")
    reason:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    reason:SetColor(1.00, 0.88, 0.35, 1)

    root.easTitle029173 = title
    root.easReason029173 = reason
    root.easStarLeft029177 = starLeft
    root.easStarRight029177 = starRight
    selector.easSuiteChoiceBanner029173 = root
    return root
end

function A:SetArchiveChoiceBanner029173(selector, abilityId, reasonText)
    local banner = self:EnsureArchiveChoiceBanner029173(selector)
    if not banner then return end
    abilityId = tonumber(abilityId) or 0
    if abilityId <= 0 then
        banner:SetHidden(true)
        return
    end
    local name = tostring(EAS_IA_First029171(GetAbilityName, abilityId) or "Best Choice")
    banner.easTitle029173:SetText("SUITE RECOMMENDS: " .. name)
    banner.easReason029173:SetText(tostring(reasonText or "Best fit for this run"))
    banner:SetHidden(false)
end

function A:SetArchiveChoiceHighlighted029171(buffControl, highlighted, reasonText)
    if not buffControl then return end
    self:EnsureArchiveChoiceGlow029171(buffControl)
    local show = highlighted == true

    if buffControl.easBestGlow029171 then buffControl.easBestGlow029171:SetHidden(not show) end
    if buffControl.easBestLabel029171 then buffControl.easBestLabel029171:SetHidden(not show) end
    if buffControl.easBestStarLeft029177 then buffControl.easBestStarLeft029177:SetHidden(not show) end
    if buffControl.easBestStarRight029177 then buffControl.easBestStarRight029177:SetHidden(not show) end

    -- Use ZOS's own selector highlight. Its XML is already marked
    -- excludeFromResizeToFitExtents, so it cannot reintroduce the v0.29.171
    -- resize feedback loop. Keep normal mouse-hover selection intact on the
    -- other choices; only release a highlight that the Suite forced earlier.
    if show then
        if type(buffControl.SetHighlightHidden) == "function" then
            pcall(buffControl.SetHighlightHidden, buffControl, false)
            buffControl.easBestForcedNative029173 = true
        elseif buffControl.easBestNativeHighlight029173 then
            buffControl.easBestNativeHighlight029173:SetHidden(false)
        end
        if buffControl.nameLabel and buffControl.nameLabel.SetColor then
            buffControl.nameLabel:SetColor(0.55, 1.00, 0.30, 1)
        end
    else
        if buffControl.easBestForcedNative029173 then
            local isMouseSelected = buffControl.manager and buffControl.manager.selectedBuffControl == buffControl
            if not isMouseSelected and type(buffControl.SetHighlightHidden) == "function" then
                pcall(buffControl.SetHighlightHidden, buffControl, true)
            end
            buffControl.easBestForcedNative029173 = nil
        end
        if buffControl.nameLabel and buffControl.nameLabel.SetColor then
            local c = rawget(_G, "ZO_SELECTED_TEXT")
            if c and c.UnpackRGBA then
                buffControl.nameLabel:SetColor(c:UnpackRGBA())
            else
                buffControl.nameLabel:SetColor(1, 1, 1, 1)
            end
        end
    end
end

function A:UpdateArchiveChoiceSelector029171(selector)
    if not selector or not selector.control or not selector.buffControls then return false end
    if selector.control.IsHidden and selector.control:IsHidden() then
        for _, control in ipairs(selector.buffControls) do self:SetArchiveChoiceHighlighted029171(control, false) end
        self:SetArchiveChoiceBanner029173(selector, 0)
        return false
    end
    if EPC.saved and EPC.saved.infiniteArchiveChoiceAdvisor029171 == false then
        for _, control in ipairs(selector.buffControls) do self:SetArchiveChoiceHighlighted029171(control, false) end
        self:SetArchiveChoiceBanner029173(selector, 0)
        return false
    end

    local context = self:GetArchiveRunContext029171()
    local synergy = self:GetActiveArchiveSynergy029171()
    local bestControl, bestScore, bestReason = nil, -999999, ""
    local rows = {}

    for _, control in ipairs(selector.buffControls) do
        self:SetArchiveChoiceHighlighted029171(control, false)
        if control and (not control.IsHidden or not control:IsHidden()) then
            local abilityId = tonumber(control.abilityId) or 0
            if abilityId > 0 then
                local buffType, isAvatarVision = nil, false
                if type(GetAbilityEndlessDungeonBuffType) == "function" then
                    local ok, bt, avatar = pcall(GetAbilityEndlessDungeonBuffType, abilityId)
                    if ok then buffType, isAvatarVision = bt, avatar == true end
                end
                local score, reason = self:ScoreArchiveChoice029171(abilityId, buffType, isAvatarVision, context, synergy)
                rows[#rows + 1] = { abilityId = abilityId, score = score, reason = reason }
                if score > bestScore then
                    bestControl, bestScore, bestReason = control, score, reason
                end
            end
        end
    end

    if bestControl then
        self:SetArchiveChoiceHighlighted029171(bestControl, true, bestReason)
        self:SetArchiveChoiceBanner029173(selector, tonumber(bestControl.abilityId) or 0, bestReason)
        self.lastArchiveBestChoice029171 = { abilityId = tonumber(bestControl.abilityId) or 0, score = bestScore, reason = bestReason, role = context.role, arc = context.arc }
    else
        self:SetArchiveChoiceBanner029173(selector, 0)
    end
    return bestControl ~= nil
end

function A:UpdateArchiveChoiceAdvisor029171()
    local seen = false
    local keyboard = rawget(_G, "ENDLESS_DUNGEON_BUFF_SELECTOR_KEYBOARD")
    if keyboard then seen = self:UpdateArchiveChoiceSelector029171(keyboard) or seen end
    return seen
end

function A:RegisterArchiveChoiceAdvisor029171()
    if self.choiceAdvisorRegistered029171 then return end
    self.choiceAdvisorRegistered029171 = true
    local prefix = (EPC.name or "ESOAdventurerSuite") .. "_ArchiveChoice029171"

    -- The selector is deferred-initialized by ZO_Ingame, so a tiny update while
    -- it is visible is more reliable than assuming the global exists at addon
    -- load. Hidden selectors exit immediately and do no scoring work.
    EVENT_MANAGER:RegisterForUpdate(prefix .. "_Poll", 750, function()
        A:UpdateArchiveChoiceAdvisor029171()
    end)

    if EVENT_ENDLESS_DUNGEON_BUFF_SELECTOR_CHOICES_RECEIVED then
        EVENT_MANAGER:RegisterForEvent(prefix .. "_Choices", EVENT_ENDLESS_DUNGEON_BUFF_SELECTOR_CHOICES_RECEIVED, function()
            zo_callLater(function() A:UpdateArchiveChoiceAdvisor029171() end, 80)
        end)
    end
end

local EAS_IA_InitializeBase029171 = InitializeImplArch
InitializeImplArch = function(self)
    EAS_IA_InitializeBase029171(self)
    self:RegisterArchiveChoiceAdvisor029171()
end
