-- Arclight Taunt 1.3.1 | Observed ESO target markers
-- Display metadata only; shared taunt-effect observation stays in Tracking.lua.
local A = ArclightTaunt
local Now = A.Now
local function CorrelatedMarkerTarget(now)
    if type(A.ResolveReticleMarkerTarget) == "function" then return A.ResolveReticleMarkerTarget(now) end
end
-- Honor the current platform/addon mapper. Invalid third-party results hide
-- the symbol; no disk probes, hardcoded replacement set or private UI hooks.
local function GetTargetMarkerTexture(marker)
    if type(marker) ~= "number" or marker ~= marker or marker <= 0
        or marker == math.huge or marker % 1 ~= 0
        or type(ZO_GetPlatformTargetMarkerIcon) ~= "function" then return end
    local ok, texture = pcall(ZO_GetPlatformTargetMarkerIcon, marker)
    if ok and type(texture) == "string" and texture ~= "" then return texture end
end
-- Marker metadata is display-only. Direct event identity takes priority.
-- A separately validated own-effect correlation may update symbols only;
-- it never grants direct identity, death authority or a new taunt deadline.
local function ObserveTargetMarker(target, unitTag)
    if not A.saved.showTargetMarkers then return false end
    if type(unitTag) ~= "string" or unitTag == "" or not DoesUnitExist(unitTag) then
        -- Follow-up effect events may omit their usable unitTag. The current
        -- reticle is still safe only when its prior direct event identity
        -- belongs to this exact live record; timer-based focus is not proof.
        if A.reticleUnitId ~= target.unitId or A.targets[target.unitId] ~= target
            or not DoesUnitExist("reticleover") then return false end
        unitTag = "reticleover"
    end
    local marker, texture
    if EVENT_TARGET_MARKER_UPDATE and type(GetUnitTargetMarkerType) == "function"
        and type(ZO_GetPlatformTargetMarkerIcon) == "function" then
        local ok, value = pcall(GetUnitTargetMarkerType, unitTag)
        if ok and value ~= TARGET_MARKER_TYPE_NONE then
            marker, texture = value, GetTargetMarkerTexture(value)
        end
    end
    if type(texture) ~= "string" or texture == "" then marker, texture = nil, nil end
    local changed = target.targetMarker ~= marker or target.targetMarkerTexture ~= texture
    if changed and marker then
        -- The author confirmed native ESO marks have one owner per symbol.
        -- An accepted observation invalidates that symbol's old
        -- owner only. Never scan rows on unchanged observations or use the
        -- symbol itself as proof of the new target's combat identity.
        for _, other in pairs(A.targets) do
            if other ~= target and other.targetMarker == marker then
                other.targetMarker, other.targetMarkerTexture = nil, nil
            end
        end
    end
    target.targetMarker, target.targetMarkerTexture = marker, texture
    return changed
end

local markerRefreshTarget, markerRefreshAt
local function CancelTargetMarkerRefresh(target)
    if target == nil or markerRefreshTarget == target then
        markerRefreshTarget, markerRefreshAt = nil, nil
    end
end
local function QueueTargetMarkerRefresh(target, correlated)
    if not A.saved.showTargetMarkers
        or (A.reticleUnitId ~= target.unitId and not (correlated and A.reticleUnitId == nil))
        or A.targets[target.unitId] ~= target then return end
    -- A marker notification can precede the next usable native observation.
    -- Settle once on the existing HUD tick; no additional timer or scan.
    markerRefreshTarget, markerRefreshAt = target, Now() + 0.1
end
local function RefreshTargetMarker(now)
    if not markerRefreshAt or now < markerRefreshAt then return end
    local target = markerRefreshTarget
    markerRefreshTarget, markerRefreshAt = nil, nil
    if not A.saved.showTargetMarkers or target.dead or A.targets[target.unitId] ~= target then return end
    if A.reticleUnitId ~= target.unitId then
        -- Re-read the current own effect instead of retaining inferred identity.
        if A.reticleUnitId or CorrelatedMarkerTarget(now) ~= target then return end
    end
    ObserveTargetMarker(target, "reticleover")
end

function A.ResetTargetMarkers()
    CancelTargetMarkerRefresh()
    for _, target in pairs(A.targets) do target.targetMarker, target.targetMarkerTexture = nil, nil end
end

function A.TargetMarkersChanged()
    if not A.saved.showTargetMarkers or not next(A.targets) then return end
    -- This event has no unit payload. Correlate only the currently observed
    -- own effect, never a cached focus or an offscreen enemy's marker type.
    local identified = A.reticleUnitId and A.targets[A.reticleUnitId]
    if identified and not identified.dead then
        ObserveTargetMarker(identified, "reticleover")
        QueueTargetMarkerRefresh(identified)
    elseif not A.reticleUnitId then
        local correlated = CorrelatedMarkerTarget(Now())
        if correlated then
            ObserveTargetMarker(correlated, "reticleover")
            QueueTargetMarkerRefresh(correlated, true)
        end
    end
    A.RequestEffectTick(false)
end

function A.ConfigureTargetMarkerEvents()
    local event = EVENT_TARGET_MARKER_UPDATE
    if not event then return end
    local enabled = A.saved.showTargetMarkers and type(GetUnitTargetMarkerType) == "function"
        and type(ZO_GetPlatformTargetMarkerIcon) == "function"
    if A.targetMarkerEventEnabled == not not enabled then return end
    A.targetMarkerEventEnabled = not not enabled
    if enabled then A.EM:RegisterForEvent(A.ADDON .. "_TargetMarkers", event, A.TargetMarkersChanged)
    else A.EM:UnregisterForEvent(A.ADDON .. "_TargetMarkers", event) end
end

function A.SetTargetMarkersEnabled(enabled)
    if type(enabled) ~= "boolean" then return end
    A.saved.showTargetMarkers = enabled
    A.ConfigureTargetMarkerEvents()
    A.ResetTargetMarkers()
    local identified = A.reticleUnitId and A.targets[A.reticleUnitId]
    if enabled and identified and not identified.dead then ObserveTargetMarker(identified, "reticleover") end
    A.Tick()
end

A.GetTargetMarkerTexture = GetTargetMarkerTexture
A.ObserveTargetMarker = ObserveTargetMarker
A.QueueTargetMarkerRefresh = QueueTargetMarkerRefresh
A.RefreshTargetMarker = RefreshTargetMarker
A.CancelTargetMarkerRefresh = CancelTargetMarkerRefresh
