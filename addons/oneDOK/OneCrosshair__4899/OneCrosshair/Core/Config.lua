local O = OneCrosshair
-- Default appearance; players can override these values in the settings panel.
O.Config = {
    resourceLength = 90,        -- Arc length, percent of each quadrant (0..100).
    resourceRadius = 45.25,     -- Ring radius in ESO UI units (20..100).
    resourceThickness = 5,     -- Resource stroke thickness in UI units (1..12).
    crosshairOpacity = 0.65,   -- Custom crosshair opacity (0..1); native ESO keeps its own alpha.
    hudOpacity = 0.50,         -- Resource/GCD/shield opacity (0..1).
}
