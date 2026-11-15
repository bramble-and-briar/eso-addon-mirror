local WR = Wegesruhe

WR.floatingHooked = false
WR.blankTexture = "Wegesruhe/textures/blank.dds"

-- IMPORTANT SAFETY DESIGN
-- -----------------------
-- SetFloatingMarkerInfo is one of the few APIs that can alter ESO's 3D
-- floating quest/navigation markers, but repeated/manual calls have a long
-- history of causing hard client crashes. Wegesruhe therefore never calls it
-- on its own after initialization. We only wrap the function and alter the
-- arguments of calls that ESO (or another addon) was already going to make.
--
-- Consequence: map and compass changes are immediate. 3D world-marker changes
-- become visible at ESO's next natural floating-marker rebuild (commonly after
-- a loading screen / player activation). This is intentional for stability.

function WR:InitializeFloatingMarkers()
    if self.floatingHooked or type(SetFloatingMarkerInfo) ~= "function" then
        return
    end
    self.floatingHooked = true

    self.originalSetFloatingMarkerInfo = SetFloatingMarkerInfo
    local original = self.originalSetFloatingMarkerInfo

    function SetFloatingMarkerInfo(pinType, size, texture, breadcrumbTexture, ...)
        -- Only intercept explicitly registered 3D world-marker types.
        -- Compass-only POI types share the category table, but do not belong here.
        local managed = WR.managedFloatingPinSet[pinType] == true

        if managed then
            if not WR:IsFloatingPinVisible(pinType) then
                texture = WR.blankTexture
            end
            if not WR:AreBreadcrumbsVisible() and breadcrumbTexture and breadcrumbTexture ~= "" then
                breadcrumbTexture = WR.blankTexture
            end
        end

        return original(pinType, size, texture, breadcrumbTexture, ...)
    end
end

-- Kept as a deliberate no-op for callers inside Wegesruhe. Never manually
-- re-issue SetFloatingMarkerInfo: stability is more important than live 3D
-- marker toggling.
function WR:RefreshFloatingMarkers()
end
