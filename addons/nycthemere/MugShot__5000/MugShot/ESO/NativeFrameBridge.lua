-- =========================================================
-- MugShot - NativeFrameBridge  (ESO/NativeFrameBridge.lua)
-- Manages hiding/showing the game's built-in reticle-over
-- target frame so it doesn't overlap MugShot's frame.
--
-- The native frame is typically at the global named
-- ZO_TargetUnitFramereticleover.  We access it via pcall so
-- that a missing or renamed control never crashes the addon.
-- =========================================================

local NativeFrameBridge = {}
NativeFrameBridge.__index = NativeFrameBridge

-- ── Constructor ───────────────────────────────────────────
function NativeFrameBridge.New()
    local self = setmetatable({}, NativeFrameBridge)
    self._nativeFrame          = nil   -- the ZO control, once found
    self._foundNativeFrame     = false -- true after Start() succeeds
    self._wasHiddenByUs        = false -- track whether we hid it
    self._isReplacementActive = false -- track active suppression state
    return self
end

-- ── Start ─────────────────────────────────────────────────
-- Attempt to locate the native target frame and install suppression hook.
-- Safe to call before the frame exists; logs a warning if not found.
function NativeFrameBridge:Start()
    local ok, frame = pcall(function()
        -- ZO_TargetUnitFramereticleover is the global name used by the
        -- default UI for the reticle-over target frame control.
        return ZO_TargetUnitFramereticleover
    end)

    if ok and frame and type(frame.SetHidden) == "function" then
        self._nativeFrame      = frame
        self._foundNativeFrame = true
        MugShot.logger:Info("NativeFrameBridge: found ZO_TargetUnitFramereticleover")

        -- Hook SetHidden to prevent ESO base UI from ever unhiding while replacement is active
        if ZO_PreHook then
            ZO_PreHook(frame, "SetHidden", function(_control, hidden)
                if not hidden and self._isReplacementActive then
                    return true -- Suppress unhiding
                end
            end)
        end
    else
        MugShot.logger:Warn("NativeFrameBridge: native target frame not found — will not suppress it")
    end
end

-- ── SetReplacementActive ──────────────────────────────────
-- When active == true: hide the native frame and lock out unhiding.
-- When active == false: restore it (show it again).
-- @param  active  bool
function NativeFrameBridge:SetReplacementActive(active)
    if not self._foundNativeFrame then return end

    self._isReplacementActive = (active == true)

    local ok, err = pcall(function()
        if active then
            if not self._nativeFrame:IsHidden() then
                self._nativeFrame:SetHidden(true)
                self._wasHiddenByUs = true
            end
            if self._nativeFrame.SetAlpha then
                self._nativeFrame:SetAlpha(0)
            end
        else
            if self._wasHiddenByUs then
                if self._nativeFrame.SetAlpha then
                    self._nativeFrame:SetAlpha(1)
                end
                self._nativeFrame:SetHidden(false)
                self._wasHiddenByUs = false
            end
        end
    end)

    if not ok then
        MugShot.logger:Error("NativeFrameBridge:SetReplacementActive error: %s", tostring(err))
    end
end

-- ── Stop ──────────────────────────────────────────────────
-- Restore the native frame to visible on addon shutdown / disable.
function NativeFrameBridge:Stop()
    self:SetReplacementActive(false)
    self._foundNativeFrame = false
    self._nativeFrame      = nil
end

MugShot.NativeFrameBridge = NativeFrameBridge
MugShot.logger:Info("=== NativeFrameBridge loaded ===")
