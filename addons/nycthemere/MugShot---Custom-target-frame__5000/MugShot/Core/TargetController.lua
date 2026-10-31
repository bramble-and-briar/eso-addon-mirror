-- =========================================================
-- MugShot - TargetController  (Core/TargetController.lua)
-- Orchestrates the full data → display pipeline:
--
--   ESO events
--     └→ TargetController
--          ├→ EsoAdapter      (read raw identity, vitals, shield, effects)
--          ├→ TargetState     (store raw data)
--          ├→ TargetPolicy    (should we display?)
--          ├→ Presentation    (transform to display tables)
--          ├→ TargetFrameView (render)
--          └→ NativeFrameBridge (hide/show native frame)
-- =========================================================

local MugShot = MugShot

local TargetController = {}
TargetController.__index = TargetController

-- Localized functions for Lua 5.1 bytecode speed (Code65536 / Baertram pattern)
local ipairs             = ipairs
local tostring           = tostring
local math_max           = math.max
local GetGameTimeSeconds = GetGameTimeSeconds

local DEFAULT_CLASS_ICON = "/esoui/art/icons/class/gamepad/gp_class_dragonknight.dds"
local SAMPLE_EFFECTS = {
    { icon = "/esoui/art/icons/ability_warrior_001.dds", timerText = "15", stackText = "3" },
    { icon = "/esoui/art/icons/ability_rogue_012.dds",   timerText = "7",  stackText = "" },
    { icon = "/esoui/art/icons/ability_mage_002.dds",    timerText = "",   stackText = "" },
}

-- ── Constructor ───────────────────────────────────────────
function TargetController.New(deps)
    local self = setmetatable({}, TargetController)
    self._state         = deps.state
    self._adapter       = deps.adapter
    self._eventBindings = deps.eventBindings
    self._nativeBridge  = deps.nativeBridge
    self._view          = deps.view
    self._settings      = deps.settings
    self._inMoveMode    = false
    self._inDebugMode   = false
    self._isInTrial     = false
    self._effectsBuffer = {} -- Reusable zero-GC presentation buffer
    return self
end

-- ── Lifecycle ─────────────────────────────────────────────
function TargetController:Start()
    self._isInTrial = self._adapter:IsInTrial()
    self._nativeBridge:Start()
    self._nativeBridge:SetReplacementActive(true)
    self._eventBindings:Start(self)
    self:RefreshTarget()
    MugShot.logger:Info("TargetController: started")
end

function TargetController:Stop()
    self._eventBindings:Stop()
    self._view:SetVisible(false)
    self._nativeBridge:SetReplacementActive(false)
    self._nativeBridge:Stop()
    MugShot.logger:Info("TargetController: stopped")
end

function TargetController:ApplySettings(settings)
    self._view:ApplyLayout(settings)
end

function TargetController:GetGeneration()
    return self._state and self._state.generation or 0
end

function TargetController:IsInMoveMode()
    return self._inMoveMode == true
end

-- ── Private Helpers (DRY) ─────────────────────────────────

-- Checks whether a callback is from an older target generation
function TargetController:_IsStale(targetGeneration)
    if targetGeneration ~= nil and targetGeneration ~= self._state.generation then
        MugShot.logger:Debug("TargetController dropped stale update (gen=%s, current=%s)",
            tostring(targetGeneration), tostring(self._state.generation))
        return true
    end
    return false
end

-- Hides frame, resets view, and maintains native frame suppression
function TargetController:_ClearTarget(suppressNative)
    self._eventBindings:StopEffectTimer()
    self._view:SetVisible(false)
    self._view:Reset()
    if suppressNative ~= false then
        self._nativeBridge:SetReplacementActive(true)
    else
        self._nativeBridge:SetReplacementActive(false)
    end
end

-- Builds and applies vitals presentation table to the view
function TargetController:_UpdateVitalsView()
    local Presentation = MugShot.Presentation
    local vitalsPres = Presentation.BuildVitals(self._state, self._settings:Get())
    self._view:SetVitals(vitalsPres)
    return vitalsPres
end

-- Builds and applies effects presentation table (injects samples in move mode if empty)
function TargetController:_UpdateEffectsView()
    local Presentation = MugShot.Presentation
    local effPres = Presentation.BuildEffects(self._state, self._settings:Get(), self._effectsBuffer)
    if self._inMoveMode and #effPres == 0 then
        effPres = SAMPLE_EFFECTS
    end
    self._view:SetEffects(effPres)
    return effPres
end

-- Starts or stops the 250ms effect timer ticker depending on active timed buffs
function TargetController:_SyncEffectTimer(effects)
    local hasTimers = false
    for _, eff in ipairs(effects or self._state.effects or {}) do
        if eff.timer and eff.timer > 0 then
            hasTimers = true
            break
        end
    end
    if hasTimers then
        self._eventBindings:StartEffectTimer()
    elseif not self._inMoveMode then
        self._eventBindings:StopEffectTimer()
    end
end

-- ── Move & Debug Modes ────────────────────────────────────

function TargetController:SetMoveMode(active)
    self._inMoveMode = active
    local state = self._state

    self._view:SetMoveMode(active)

    if active then
        state:ResetForTargetChange()
        state.exists  = true
        state.unitTag = "player"

        self:RefreshMoveModeIdentity()
        state.vitals  = self._adapter:ReadVitals("player")
        state.effects = self._adapter:ReadEffects("player")

        local vitalsPres = self:_UpdateVitalsView()
        if not vitalsPres.healthKnown or not vitalsPres.healthText or vitalsPres.healthText == "" then
            self._view:SetVitals({
                healthKnown   = true,
                percentText   = "100%",
                healthText    = "100k/100k",
                healthPercent = 1.0,
                shieldPercent = 0.0,
                shield        = 0,
            })
        end

        self:_UpdateEffectsView()
        self._view:SetVisible(true)
        self:_SyncEffectTimer(state.effects)
    else
        state.unitTag = "reticleover"
        self:RefreshTarget()
    end
end

function TargetController:RefreshMoveModeIdentity()
    if not self._inMoveMode then return end
    local state    = self._state
    local settings = self._settings:Get()
    local Presentation = MugShot.Presentation

    local id = self._adapter:ReadIdentity("player")
    local playerName = (id.name and id.name ~= "" and id.name)
        or (id.displayName and id.displayName ~= "" and id.displayName)
        or GetUnitName("player")
        or MugShot.GetText("DRAG_ME_TITLE")
        or "[MugShot] Déplacez-moi !"
    id.displayName = playerName

    state.identity = id
    local idPres = Presentation.BuildIdentity(state, settings)

    local isDummyOrMissing = not idPres.portraitTexture or idPres.portraitTexture == ""
        or (type(idPres.portraitTexture) == "string" and (idPres.portraitTexture:find("campaignbrowser_guestcampaign", 1, true) or idPres.portraitTexture:find("icon_missing", 1, true)))

    if isDummyOrMissing then
        idPres.portraitTexture = (id and id.classIcon and id.classIcon ~= "" and id.classIcon) or DEFAULT_CLASS_ICON
    end

    self._view:SetIdentity(idPres)
end

function TargetController:SetDebugMode(active)
    self._inDebugMode = active
    if active then
        self._view:SetIdentity({
            displayName     = "Target Skeleton, Humanoid",
            r               = 0.84,
            g               = 0.00,
            b               = 0.00,
            portraitTexture = "/esoui/art/icons/event_witchfest_sacking_skelet.dds",
            raceIcon        = nil,
            allianceIcon    = nil,
        })
        self._view:SetVitals({
            healthKnown   = true,
            percentText   = "70%",
            healthText    = "2.1m/3m",
            healthPercent = 0.70,
            shieldPercent = 0.0,
            shield        = 0,
        })
        self._view:SetEffects({
            { icon = "/esoui/art/icons/ability_debuff_stumble.dds", timerText = "2", stackText = "" },
            { icon = "/esoui/art/icons/ability_debuff_vulnerable.dds", timerText = "3", stackText = "2" },
            { icon = "/esoui/art/icons/ability_debuff_offbalance.dds", timerText = "15", stackText = "" },
        })
        self._view:SetVisible(true)
    else
        self:RefreshTarget()
    end
end

-- ── Target & Component Refreshes ──────────────────────────

function TargetController:RefreshTarget()
    if self._inMoveMode or self._inDebugMode then
        return
    end

    local unitTag = self._state.unitTag -- "reticleover"

    if not DoesUnitExist(unitTag) then
        self:_ClearTarget(true) -- Always keep native frame suppressed while addon is running
        MugShot.logger:Debug("RefreshTarget: no target")
        return
    end

    -- 1. Squash native frame as the very first instruction upon target acquisition
    self._nativeBridge:SetReplacementActive(true)

    local state    = self._state
    local settings = self._settings:Get()
    local Presentation = MugShot.Presentation
    local TargetPolicy = MugShot.TargetPolicy

    state:ResetForTargetChange()
    state.exists   = true
    state.identity = self._adapter:ReadIdentity(unitTag)
    state.vitals   = self._adapter:ReadVitals(unitTag)
    state.effects  = self._adapter:ReadEffects(unitTag)

    if not TargetPolicy.ShouldDisplay(state, settings, self._isInTrial) then
        self:_ClearTarget(true) -- Target exists but filtered out: suppress native frame too!
        return
    end

    local idPres = Presentation.BuildIdentity(state, settings)
    self._view:SetIdentity(idPres)
    self:_UpdateVitalsView()
    self:_UpdateEffectsView()
    self._view:SetVisible(true)

    self:_SyncEffectTimer(state.effects)
    MugShot.logger:Debug("RefreshTarget: target=%s exists=true portrait=%s", state.identity.name or "?", tostring(idPres and idPres.portraitTexture or "nil"))
end

function TargetController:OnZoneChanged()
    self._isInTrial = self._adapter:IsInTrial()
    if not self._inMoveMode and not self._inDebugMode then
        self:RefreshTarget()
    end
end

function TargetController:OnTargetDeath()
    if self._inMoveMode or self._inDebugMode then return end
    if self._state then
        self._state.vitals.isDead = true
    end
    self:_ClearTarget()
end

function TargetController:RefreshVitals(cur, max, _effectiveMax, targetGeneration, unitTag)
    if self._inDebugMode or not self._state.exists or self:_IsStale(targetGeneration) then
        return
    end

    if self._inMoveMode and unitTag ~= "player" then
        return
    end

    local state = self._state
    local isDead = (cur <= 0) or IsUnitDead(state.unitTag)
    if isDead and not self._inMoveMode then
        state.vitals.isDead = true
        self:_ClearTarget()
        return
    end

    state.vitals.isDead        = false
    state.vitals.healthKnown   = true
    state.vitals.currentHealth = cur
    state.vitals.maxHealth     = max
    state.vitals.shield        = self._adapter:ReadVitals(state.unitTag).shield or 0

    if not self._inMoveMode then
        self:RefreshIdentity(false, state.generation)
    end

    self:_UpdateVitalsView()
end

function TargetController:RefreshIdentity(force, targetGeneration, unitTag)
    if self._inMoveMode then
        if unitTag and unitTag ~= "player" then return end
        self:RefreshMoveModeIdentity()
        return
    end
    if self._inDebugMode or not self._state.exists or self:_IsStale(targetGeneration) then
        return
    end

    local state = self._state
    local id = self._adapter:ReadIdentity(state.unitTag)
    if not id then return end

    local Presentation = MugShot.Presentation
    if force or not state.identity or id.reaction ~= state.identity.reaction or id.name ~= state.identity.name then
        state.identity = id
        local idPres = Presentation.BuildIdentity(state, self._settings:Get())
        self._view:SetIdentity(idPres)
    end
end

function TargetController:RefreshShield(targetGeneration, unitTag)
    if self._inDebugMode or not self._state.exists or self:_IsStale(targetGeneration) then
        return
    end

    if self._inMoveMode and unitTag ~= "player" then
        return
    end

    self._state.vitals.shield = self._adapter:ReadVitals(self._state.unitTag).shield or 0
    self:_UpdateVitalsView()
end

function TargetController:RefreshEffects(targetGeneration, unitTag)
    if self._inDebugMode or not self._state.exists or self:_IsStale(targetGeneration) then
        return
    end

    if self._inMoveMode and unitTag ~= "player" then
        return
    end

    local effects = self._adapter:ReadEffects(self._state.unitTag)
    self._state.effects = effects

    self:_UpdateEffectsView()
    self:_SyncEffectTimer(effects)
end

function TargetController:UpdateEffectTimers(targetGeneration)
    if self._inDebugMode or not self._state.exists or #self._state.effects == 0 or self:_IsStale(targetGeneration) then
        return
    end

    local now = GetGameTimeSeconds() or 0
    local anyActive = false

    for _, eff in ipairs(self._state.effects) do
        if eff.timeEnding and eff.timeEnding > 0 then
            local rem = eff.timeEnding - now
            if rem > 0 then
                eff.timer = rem
                anyActive = true
            else
                eff.timer = 0
            end
        end
    end

    self:_UpdateEffectsView()

    if not anyActive and not self._inMoveMode then
        self._eventBindings:StopEffectTimer()
    end
end

MugShot.TargetController = TargetController
MugShot.logger:Info("=== TargetController loaded ===")
