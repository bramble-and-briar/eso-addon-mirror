-- Arclight Taunt | Observed ESO target markers
-- Display metadata only; shared taunt-effect observation stays in Tracking.lua.
local A = ArclightTaunt
local Now = A.Now
-- Other add-ons may replace the icon mapper. A bad result or Lua error in
-- that mapper should affect only the symbol, leaving the taunt handler intact.
local VALID_MARKERS = {
    [TARGET_MARKER_TYPE_ONE]=true, [TARGET_MARKER_TYPE_TWO]=true,
    [TARGET_MARKER_TYPE_THREE]=true, [TARGET_MARKER_TYPE_FOUR]=true,
    [TARGET_MARKER_TYPE_FIVE]=true, [TARGET_MARKER_TYPE_SIX]=true,
    [TARGET_MARKER_TYPE_SEVEN]=true, [TARGET_MARKER_TYPE_EIGHT]=true,
}
local function GetTargetMarkerTexture(marker)
    if not VALID_MARKERS[marker] or type(ZO_GetPlatformTargetMarkerIcon) ~= "function" then return end
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
    local marker = GetUnitTargetMarkerType(unitTag)
    if marker == TARGET_MARKER_TYPE_NONE then marker = nil
    elseif not VALID_MARKERS[marker] then return false end
    local texture = marker and GetTargetMarkerTexture(marker)
    local changed = target.targetMarker ~= marker or target.targetMarkerTexture ~= texture
    if marker and target.targetMarker ~= marker then
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
        if A.reticleUnitId or A.ResolveReticleMarkerTarget(now) ~= target then return end
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
        local correlated = A.ResolveReticleMarkerTarget(Now())
        if correlated then
            ObserveTargetMarker(correlated, "reticleover")
            QueueTargetMarkerRefresh(correlated, true)
        end
    end
    A.RequestEffectTick(false)
end

function A.ConfigureTargetMarkerEvents()
    local enabled = A.saved.showTargetMarkers
    if A.targetMarkerEventEnabled == enabled then return end
    A.targetMarkerEventEnabled = enabled
    if enabled then A.EM:RegisterForEvent(A.ADDON .. "_TargetMarkers", EVENT_TARGET_MARKER_UPDATE, A.TargetMarkersChanged)
    else A.EM:UnregisterForEvent(A.ADDON .. "_TargetMarkers", EVENT_TARGET_MARKER_UPDATE) end
end

function A.SetTargetMarkersEnabled(enabled)
    if type(enabled) ~= "boolean" then return end
    local changed = A.saved.showTargetMarkers ~= enabled
    A.saved.showTargetMarkers = enabled
    A.ConfigureTargetMarkerEvents()
    if changed then A.ResetTargetMarkers() end
    local identified = A.reticleUnitId and A.targets[A.reticleUnitId]
    if enabled and identified and not identified.dead then
        changed = ObserveTargetMarker(identified, "reticleover") or changed
    end
    if changed then A.Tick() end
end

A.GetTargetMarkerTexture = GetTargetMarkerTexture
A.ObserveTargetMarker = ObserveTargetMarker
A.QueueTargetMarkerRefresh = QueueTargetMarkerRefresh
A.RefreshTargetMarker = RefreshTargetMarker
A.CancelTargetMarkerRefresh = CancelTargetMarkerRefresh
