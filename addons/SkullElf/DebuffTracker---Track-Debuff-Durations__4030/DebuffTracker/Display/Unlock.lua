-- Move mode: every enabled tracker shows sample entries with a gold frame and name tag, can be
-- dragged, and snaps to an optional on-screen grid (with highlighted center lines).

local DT = DebuffTracker
local Unlock = DT.Unlock
local WM = WINDOW_MANAGER

local grid
local lines = {}
local builtFor

local function BuildGrid(size)
    if not grid then
        grid = WM:CreateTopLevelWindow("DebuffTracker5_Grid")
        grid:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 0, 0)
        grid:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, 0, 0)
        grid:SetMouseEnabled(false)
        grid:SetDrawLayer(DL_BACKGROUND)
        grid:SetHidden(true)
    end
    if builtFor == size then return end
    builtFor = size
    for _, l in ipairs(lines) do l:SetHidden(true) end
    local w, h = GuiRoot:GetWidth(), GuiRoot:GetHeight()
    local cx, cy = w / 2, h / 2
    local used = 0
    local function Line(x, y, lw, lh, center)
        used = used + 1
        local l = lines[used]
        if not l then
            l = WM:CreateControl(nil, grid, CT_BACKDROP)
            l:SetEdgeColor(0, 0, 0, 0)
            lines[used] = l
        end
        l:ClearAnchors()
        l:SetAnchor(TOPLEFT, grid, TOPLEFT, x, y)
        l:SetDimensions(lw, lh)
        if center then l:SetCenterColor(0.953, 0.824, 0.478, 0.55) else l:SetCenterColor(1, 1, 1, 0.08) end
        l:SetHidden(false)
    end
    -- Lines are laid out from the center so the center lines are exact.
    local k = 0
    while cx + k * size <= w or cx - k * size >= 0 do
        if cx + k * size <= w then Line(cx + k * size, 0, 1, h, k == 0) end
        if k > 0 and cx - k * size >= 0 then Line(cx - k * size, 0, 1, h, false) end
        k = k + 1
    end
    k = 0
    while cy + k * size <= h or cy - k * size >= 0 do
        if cy + k * size <= h then Line(0, cy + k * size, w, 1, k == 0) end
        if k > 0 and cy - k * size >= 0 then Line(0, cy - k * size, w, 1, false) end
        k = k + 1
    end
end

function Unlock.Set(on)
    DT.unlocked = on == true
    local s = DT.Profiles.Settings()
    if DT.unlocked and s.showGrid then
        BuildGrid(math.max(4, s.gridSize or 16))
        grid:SetHidden(false)
    elseif grid then
        grid:SetHidden(true)
    end
    if DT.unlocked and SCENE_MANAGER:IsShowingBaseScene() then
        -- Dragging needs the mouse cursor while on the HUD.
        SCENE_MANAGER:SetInUIMode(true)
    end
    DT.Displays.ApplyTiers()
    -- locked again: the trackers are back on the editor's tier, where they'd now sit over it (5.21.12: "the editor
    -- doesn't come back to being the top layer over them") -- the editor goes back to the front of that tier
    local editor = DT.UI and DT.UI.window
    if not DT.unlocked and editor and editor.BringWindowToTop and ((DT.UI.IsShowing and DT.UI.IsShowing()) or not editor:IsHidden()) then
        editor:BringWindowToTop()
    end
    DT.Engine.RequestUpdate()
    if DT.UI.Refresh then DT.UI.Refresh() end
    DT.Util.Print(DT.unlocked and DT.L("Move mode ON: drag the windows, then lock again.") or DT.L("Move mode OFF."))
end

function Unlock.Toggle()
    Unlock.Set(not DT.unlocked)
end

function Unlock.RefreshGrid()
    builtFor = nil
    if DT.unlocked then Unlock.Set(true) end
end
